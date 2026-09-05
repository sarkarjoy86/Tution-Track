import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../services/firebase_auth_service.dart';

/// Authentication state provider
class AuthProvider extends ChangeNotifier {
  final FirebaseAuthService _authService = FirebaseAuthService();

  UserModel? _user;
  bool _isLoading = false;
  bool _isInitialized = false;
  String? _errorMessage;

  // Getters
  UserModel? get user => _user;
  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized;
  bool get isLoggedIn => _user != null;
  String? get errorMessage => _errorMessage;

  /// Initialize auth state (check if user is already signed in)
  Future<void> initialize() async {
    if (_isInitialized) return;

    _isLoading = true;
    notifyListeners();

    try {
      final firebaseUser = _authService.currentUser;
      if (firebaseUser != null) {
        _user = await _buildUserModel(firebaseUser);
      }
    } catch (e) {
      debugPrint('Auth init error: $e');
    }

    _isLoading = false;
    _isInitialized = true;
    notifyListeners();
  }

  /// Login with email/password
  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final firebaseUser = await _authService.signInWithEmail(email, password);
      if (firebaseUser != null) {
        _user = await _buildUserModel(firebaseUser);
        _isLoading = false;
        notifyListeners();
        return true;
      }
      _errorMessage = 'Login failed';
    } on FirebaseAuthException catch (e) {
      _errorMessage = _mapAuthError(e.code);
    } catch (e) {
      _errorMessage = 'An unexpected error occurred';
      debugPrint('Login error: $e');
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  /// Register new account
  Future<bool> register(String name, String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final firebaseUser = await _authService.registerWithEmail(name, email, password);
      if (firebaseUser != null) {
        _user = await _buildUserModel(firebaseUser);
        _isLoading = false;
        notifyListeners();
        return true;
      }
      _errorMessage = 'Registration failed';
    } on FirebaseAuthException catch (e) {
      _errorMessage = _mapAuthError(e.code);
    } catch (e) {
      _errorMessage = 'An unexpected error occurred';
      debugPrint('Register error: $e');
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  /// Google Sign-In
  Future<bool> googleSignIn() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final firebaseUser = await _authService.signInWithGoogle();

      if (firebaseUser == null) {
        _errorMessage = 'Google sign-in was cancelled';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      _user = await _buildUserModel(firebaseUser);
      _isLoading = false;
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      _errorMessage = _mapAuthError(e.code);
    } catch (e) {
      _errorMessage = 'Google sign-in failed. Please try again.';
      debugPrint('Google sign-in error: $e');
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  /// Forgot password
  Future<bool> forgotPassword(String email) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _authService.sendPasswordResetEmail(email);
      _isLoading = false;
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      _errorMessage = _mapAuthError(e.code);
    } catch (e) {
      _errorMessage = 'An unexpected error occurred';
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  /// Logout
  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();

    await _authService.signOut();
    _user = null;
    _isLoading = false;
    notifyListeners();
  }

  /// Send email verification to current user
  Future<bool> sendEmailVerification() async {
    _errorMessage = null;
    try {
      await _authService.sendEmailVerification();
      return true;
    } on FirebaseAuthException catch (e) {
      _errorMessage = _mapAuthError(e.code);
      debugPrint('Send email verification error: ${e.code} - ${e.message}');
      return false;
    } catch (e) {
      _errorMessage = 'Failed to send verification email. Please try again.';
      debugPrint('Send email verification error: $e');
      return false;
    }
  }

  /// Check if email is verified (reloads user from Firebase)
  Future<bool> checkEmailVerification() async {
    try {
      final user = await _authService.reloadCurrentUser();
      if (user != null && user.emailVerified) {
        _user = _user?.copyWith(isEmailVerified: true);
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Check email verification error: $e');
      return false;
    }
  }

  /// Whether the current user's email is verified
  bool get isEmailVerified => _authService.isEmailVerified;

  /// Clear error
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// Build UserModel from Firebase User + optional Firestore data
  Future<UserModel> _buildUserModel(User firebaseUser) async {
    // Try to get additional data from Firestore profile
    String authProvider = 'local';
    DateTime createdAt = firebaseUser.metadata.creationTime ?? DateTime.now();

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(firebaseUser.uid)
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        authProvider = data['authProvider'] ?? 'local';
        if (data['createdAt'] is Timestamp) {
          createdAt = (data['createdAt'] as Timestamp).toDate();
        }
      }
    } catch (_) {
      // Server fetch failed (likely offline) — try loading from Firestore cache
      try {
        final cachedDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(firebaseUser.uid)
            .get(const GetOptions(source: Source.cache));

        if (cachedDoc.exists) {
          final data = cachedDoc.data()!;
          authProvider = data['authProvider'] ?? 'local';
          if (data['createdAt'] is Timestamp) {
            createdAt = (data['createdAt'] as Timestamp).toDate();
          }
        }
      } catch (_) {
        // No cached profile either — use Firebase Auth metadata as fallback
      }
    }

    return UserModel(
      id: firebaseUser.uid,
      name: firebaseUser.displayName ?? 'Tutor',
      email: firebaseUser.email ?? '',
      authProvider: authProvider,
      isEmailVerified: firebaseUser.emailVerified,
      createdAt: createdAt,
    );
  }

  /// Map Firebase Auth error codes to user-friendly messages
  String _mapAuthError(String code) {
    switch (code) {
      case 'user-not-found':
        return 'No account found with this email.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'Invalid email or password.';
      case 'email-already-in-use':
        return 'An account with this email already exists.';
      case 'weak-password':
        return 'Password is too weak. Use at least 6 characters.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'network-request-failed':
        return 'No internet connection. Please check your network.';
      case 'user-disabled':
        return 'This account has been disabled.';
      default:
        return 'Authentication failed. Please try again.';
    }
  }
}
