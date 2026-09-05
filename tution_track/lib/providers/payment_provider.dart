import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/payment_model.dart';
import '../services/firestore_service.dart';

/// Provider for managing postpaid payment transactions and ledger
class PaymentProvider extends ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();

  List<PaymentModel> _payments = [];
  bool _isLoading = false;
  String? _errorMessage;
  double _totalCollected = 0.0;

  List<PaymentModel> get payments => _payments;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  double get totalCollected => _totalCollected;

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  /// Fetch payment history for a specific student
  Future<void> fetchPayments(String studentId) async {
    if (_uid == null) return;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _payments = await _firestoreService.getPayments(_uid!, studentId);
      _totalCollected = _payments.fold<double>(0.0, (sum, p) => sum + p.amount);
    } catch (e) {
      _errorMessage = 'Failed to load payment history';
      debugPrint('Fetch payments error: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Add a new payment transaction (optimistic)
  Future<PaymentModel?> addPayment(
    String studentId,
    Map<String, dynamic> data,
  ) async {
    if (_uid == null) return null;

    final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
    final amount = (data['amount'] as num?)?.toDouble() ?? 0.0;
    final paymentDate = data['paymentDate'] is DateTime
        ? data['paymentDate'] as DateTime
        : (data['paymentDate'] != null
            ? DateTime.tryParse(data['paymentDate'].toString()) ?? DateTime.now()
            : DateTime.now());

    final optimisticPayment = PaymentModel(
      id: tempId,
      studentId: studentId,
      tutorId: _uid!,
      amount: amount,
      paymentDate: paymentDate,
      period: data['period'] as String? ?? '',
      notes: data['notes'] as String? ?? '',
      createdAt: DateTime.now(),
    );

    // 1. Optimistic insert
    _payments.insert(0, optimisticPayment);
    _totalCollected += amount;
    _errorMessage = null;
    notifyListeners();

    try {
      final payment = await _firestoreService.addPayment(_uid!, studentId, data);
      final index = _payments.indexWhere((p) => p.id == tempId);
      if (index != -1) {
        _payments[index] = payment;
      }
      notifyListeners();
      return payment;
    } catch (e) {
      // Revert optimistic insert on error
      _payments.removeWhere((p) => p.id == tempId);
      _totalCollected -= amount;
      _errorMessage = 'Failed to record payment';
      debugPrint('Add payment error: $e');
      notifyListeners();
      return null;
    }
  }

  /// Delete a payment transaction (optimistic)
  Future<bool> deletePayment(String studentId, String paymentId) async {
    if (_uid == null) return false;

    final index = _payments.indexWhere((p) => p.id == paymentId);
    if (index == -1) return false;

    final removedPayment = _payments[index];
    _payments.removeAt(index);
    _totalCollected -= removedPayment.amount;
    notifyListeners();

    try {
      await _firestoreService.deletePayment(_uid!, studentId, paymentId);
      return true;
    } catch (e) {
      // Revert deletion on failure
      _payments.insert(index, removedPayment);
      _totalCollected += removedPayment.amount;
      _errorMessage = 'Failed to delete payment';
      debugPrint('Delete payment error: $e');
      notifyListeners();
      return false;
    }
  }

  /// Get total fees collected for any student
  Future<double> getStudentTotalFees(String studentId) async {
    if (_uid == null) return 0.0;
    try {
      return await _firestoreService.getTotalFeesCollected(_uid!, studentId);
    } catch (e) {
      return 0.0;
    }
  }

  void clearPayments() {
    _payments = [];
    _totalCollected = 0.0;
    notifyListeners();
  }
}
