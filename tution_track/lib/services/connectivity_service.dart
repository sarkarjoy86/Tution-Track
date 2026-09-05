import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

/// Lightweight connectivity tracker for offline-first UI indicators.
///
/// Wraps [Connectivity] from `connectivity_plus` to expose a simple
/// [isOnline] boolean and a stream of connectivity change events.
class ConnectivityService extends ChangeNotifier {
  /// Static instance for non-widget access (e.g., FirestoreService).
  /// Set once in constructor; safe because only one instance is created via MultiProvider.
  static ConnectivityService? _instance;
  static ConnectivityService? get instance => _instance;

  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  bool _isOnline = true;
  bool _wasOffline = false; // tracks transition for "Back Online" toast
  DateTime? _wentOfflineAt;

  // ── Getters ──────────────────────────────────────────

  /// Whether the device currently has network connectivity.
  bool get isOnline => _isOnline;

  /// Whether the device is currently offline.
  bool get isOffline => !_isOnline;

  /// Whether the device just came back online after being offline.
  /// Reset after being read once (consumed).
  bool consumeBackOnlineEvent() {
    if (_wasOffline && _isOnline) {
      _wasOffline = false;
      return true;
    }
    return false;
  }

  /// How long the device has been offline (null if online).
  Duration? get offlineDuration {
    if (_wentOfflineAt == null || _isOnline) return null;
    return DateTime.now().difference(_wentOfflineAt!);
  }

  // ── Lifecycle ────────────────────────────────────────

  ConnectivityService() {
    _instance = this;
    _init();
  }

  Future<void> _init() async {
    // Get initial status
    try {
      final results = await _connectivity.checkConnectivity();
      _updateStatus(results);
    } catch (e) {
      debugPrint('ConnectivityService: initial check failed: $e');
      // Assume online if check fails — Firestore cache will handle it
      _isOnline = true;
    }

    // Listen for changes
    _subscription = _connectivity.onConnectivityChanged.listen(
      _updateStatus,
      onError: (e) {
        debugPrint('ConnectivityService: stream error: $e');
      },
    );
  }

  void _updateStatus(List<ConnectivityResult> results) {
    final wasOnline = _isOnline;
    _isOnline = results.any((r) => r != ConnectivityResult.none);

    if (wasOnline && !_isOnline) {
      // Just went offline
      _wentOfflineAt = DateTime.now();
      _wasOffline = true;
    } else if (!wasOnline && _isOnline) {
      // Just came back online
      _wentOfflineAt = null;
      // _wasOffline stays true so consumeBackOnlineEvent() fires once
    }

    notifyListeners();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
