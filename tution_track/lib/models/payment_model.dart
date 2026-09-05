import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/formatters.dart';

/// Model representing a postpaid fee payment record
class PaymentModel {
  final String id;
  final String studentId;
  final String tutorId;
  final double amount;
  final DateTime paymentDate;
  final String period; // e.g. "August 2026" or "Aug 2026"
  final String notes;
  final DateTime createdAt;

  const PaymentModel({
    required this.id,
    required this.studentId,
    this.tutorId = '',
    required this.amount,
    required this.paymentDate,
    required this.period,
    this.notes = '',
    required this.createdAt,
  });

  /// Create from Firestore document snapshot
  factory PaymentModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return PaymentModel(
      id: doc.id,
      studentId: data['studentId'] ?? '',
      tutorId: data['tutorId'] ?? '',
      amount: (data['amount'] ?? 0).toDouble(),
      paymentDate: data['paymentDate'] is Timestamp
          ? (data['paymentDate'] as Timestamp).toDate()
          : (data['paymentDate'] != null
              ? DateTime.parse(data['paymentDate'])
              : DateTime.now()),
      period: data['period'] ?? '',
      notes: data['notes'] ?? '',
      createdAt: data['createdAt'] is Timestamp
          ? (data['createdAt'] as Timestamp).toDate()
          : (data['createdAt'] != null
              ? DateTime.parse(data['createdAt'])
              : DateTime.now()),
    );
  }

  /// Create from JSON map
  factory PaymentModel.fromJson(Map<String, dynamic> json) {
    return PaymentModel(
      id: json['id'] ?? json['_id'] ?? '',
      studentId: json['studentId'] ?? '',
      tutorId: json['tutorId'] ?? '',
      amount: (json['amount'] ?? 0).toDouble(),
      paymentDate: json['paymentDate'] is Timestamp
          ? (json['paymentDate'] as Timestamp).toDate()
          : (json['paymentDate'] != null
              ? DateTime.parse(json['paymentDate'])
              : DateTime.now()),
      period: json['period'] ?? '',
      notes: json['notes'] ?? '',
      createdAt: json['createdAt'] is Timestamp
          ? (json['createdAt'] as Timestamp).toDate()
          : (json['createdAt'] != null
              ? DateTime.parse(json['createdAt'])
              : DateTime.now()),
    );
  }

  /// Convert to Firestore map
  Map<String, dynamic> toMap() {
    return {
      'studentId': studentId,
      'tutorId': tutorId,
      'amount': amount,
      'paymentDate': Timestamp.fromDate(paymentDate),
      'period': period,
      'notes': notes,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  Map<String, dynamic> toJson() => toMap();

  /// Formatted Taka amount string (e.g. "৳ 5,000")
  String get formattedAmount => AppFormatters.formatTaka(amount);

  /// Standardized ordinal date (e.g. "4th Sep, 2026")
  String get formattedPaymentDate => AppFormatters.formatDateOrdinal(paymentDate);

  PaymentModel copyWith({
    String? id,
    String? studentId,
    String? tutorId,
    double? amount,
    DateTime? paymentDate,
    String? period,
    String? notes,
    DateTime? createdAt,
  }) {
    return PaymentModel(
      id: id ?? this.id,
      studentId: studentId ?? this.studentId,
      tutorId: tutorId ?? this.tutorId,
      amount: amount ?? this.amount,
      paymentDate: paymentDate ?? this.paymentDate,
      period: period ?? this.period,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
