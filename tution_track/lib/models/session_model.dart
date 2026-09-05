import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../utils/formatters.dart';

enum SessionType {
  scheduled,
  makeup,
  extra;

  String toDbString() {
    switch (this) {
      case SessionType.scheduled:
        return 'SCHEDULED';
      case SessionType.makeup:
        return 'MAKEUP';
      case SessionType.extra:
        return 'EXTRA';
    }
  }

  static SessionType fromString(String? val) {
    if (val == null) return SessionType.scheduled;
    switch (val.toUpperCase().trim()) {
      case 'MAKEUP':
        return SessionType.makeup;
      case 'EXTRA':
        return SessionType.extra;
      case 'SCHEDULED':
      default:
        return SessionType.scheduled;
    }
  }
}

/// Session model representing a single attendance check-in
class SessionModel {
  final String id;
  final String tutorId;
  final String studentId;
  final DateTime timestamp;
  final String dateString; // "YYYY-MM-DD"
  final String dayOfWeek; // "Monday", "Friday", etc.
  final String monthYear; // "YYYY-MM"
  final String timeSlot; // "Morning", "Noon", "Afternoon", "Evening", "Night"
  final bool isExtraClass; // Legacy flag: Taken on unscheduled day
  final String sessionType; // 'SCHEDULED', 'MAKEUP', 'EXTRA'
  final String replacesMissedDate; // 'YYYY-MM-DD' if sessionType == 'MAKEUP'
  final String notes;

  const SessionModel({
    required this.id,
    this.tutorId = '',
    required this.studentId,
    required this.timestamp,
    required this.dateString,
    required this.dayOfWeek,
    required this.monthYear,
    this.timeSlot = 'Morning',
    this.isExtraClass = false,
    this.sessionType = 'SCHEDULED',
    this.replacesMissedDate = '',
    this.notes = '',
  });

  /// Enum representation of session classification
  SessionType get type => SessionType.fromString(sessionType);

  /// Check whether this session is an automated or manual makeup class
  bool get isMakeup => type == SessionType.makeup;

  /// Check whether this session is a bonus/pure extra class beyond quota
  bool get isPureExtra => type == SessionType.extra || (isExtraClass && type != SessionType.makeup);

  /// Check whether this session is a regular scheduled class
  bool get isScheduled => type == SessionType.scheduled && !isExtraClass;

  /// Optional DateTime representation of replaced missed date
  DateTime? get replacesMissedDateTime {
    if (replacesMissedDate.isEmpty) return null;
    try {
      final parts = replacesMissedDate.split('-');
      if (parts.length == 3) {
        return DateTime(
          int.parse(parts[0]),
          int.parse(parts[1]),
          int.parse(parts[2]),
        );
      }
    } catch (_) {}
    return null;
  }

  /// Formatted date of replaced missed session (e.g., "Tue, 1st Sep")
  String get formattedReplacedDate {
    if (replacesMissedDate.isEmpty) return '';
    try {
      final parts = replacesMissedDate.split('-');
      if (parts.length == 3) {
        final d = DateTime(
          int.parse(parts[0]),
          int.parse(parts[1]),
          int.parse(parts[2]),
        );
        final dayAbbr = DateFormat('EEE').format(d);
        final ordinal = AppFormatters.formatDateOrdinal(d);
        // e.g. "Tue, 1st Sep"
        final monthDay = ordinal.split(',').first.trim();
        return '$dayAbbr, $monthDay';
      }
    } catch (_) {}
    return replacesMissedDate;
  }

  /// Create from a JSON map (backwards compatible)
  factory SessionModel.fromJson(Map<String, dynamic> json) {
    final parsedTime = json['timestamp'] != null
        ? (json['timestamp'] is Timestamp
            ? (json['timestamp'] as Timestamp).toDate()
            : DateTime.parse(json['timestamp'].toString()))
        : DateTime.now();

    final rawReplaced = json['replacesMissedDate']?.toString() ?? '';
    final rawType = json['sessionType']?.toString() ?? '';
    final legacyExtra = json['isExtraClass'] == true;

    final resolvedType = rawType.isNotEmpty
        ? rawType
        : (legacyExtra
            ? (rawReplaced.isNotEmpty ? 'MAKEUP' : 'EXTRA')
            : 'SCHEDULED');

    return SessionModel(
      id: json['_id'] ?? json['id'] ?? '',
      tutorId: json['tutorId'] ?? '',
      studentId: json['studentId'] ?? '',
      timestamp: parsedTime,
      dateString: json['dateString'] ?? '',
      dayOfWeek: json['dayOfWeek'] ?? '',
      monthYear: json['monthYear'] ?? '',
      timeSlot: json['timeSlot'] ?? AppFormatters.getTimeSlot(parsedTime),
      isExtraClass: legacyExtra || resolvedType != 'SCHEDULED',
      sessionType: resolvedType,
      replacesMissedDate: rawReplaced,
      notes: json['notes'] ?? '',
    );
  }

  /// Create from a Firestore document snapshot
  factory SessionModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final parsedTime = data['timestamp'] is Timestamp
        ? (data['timestamp'] as Timestamp).toDate()
        : DateTime.now();

    final rawReplaced = data['replacesMissedDate']?.toString() ?? '';
    final rawType = data['sessionType']?.toString() ?? '';
    final legacyExtra = data['isExtraClass'] == true;

    final resolvedType = rawType.isNotEmpty
        ? rawType
        : (legacyExtra
            ? (rawReplaced.isNotEmpty ? 'MAKEUP' : 'EXTRA')
            : 'SCHEDULED');

    return SessionModel(
      id: doc.id,
      tutorId: data['tutorId'] ?? '',
      studentId: data['studentId'] ?? '',
      timestamp: parsedTime,
      dateString: data['dateString'] ?? '',
      dayOfWeek: data['dayOfWeek'] ?? '',
      monthYear: data['monthYear'] ?? '',
      timeSlot: data['timeSlot'] ?? AppFormatters.getTimeSlot(parsedTime),
      isExtraClass: legacyExtra || resolvedType != 'SCHEDULED',
      sessionType: resolvedType,
      replacesMissedDate: rawReplaced,
      notes: data['notes'] ?? '',
    );
  }

  /// Convert to Firestore map
  Map<String, dynamic> toMap() {
    return {
      'tutorId': tutorId,
      'studentId': studentId,
      'timestamp': Timestamp.fromDate(timestamp),
      'dateString': dateString,
      'dayOfWeek': dayOfWeek,
      'monthYear': monthYear,
      'timeSlot': timeSlot,
      'isExtraClass': isExtraClass || sessionType != 'SCHEDULED',
      'sessionType': sessionType,
      'replacesMissedDate': replacesMissedDate,
      'notes': notes,
    };
  }

  Map<String, dynamic> toJson() => toMap();

  /// Standardized ordinal date string (e.g. "4th Sep, 2026")
  String get formattedOrdinalDate => AppFormatters.formatDateOrdinal(timestamp);

  /// Clock time (e.g. "2:30 PM")
  String get formattedClockTime {
    final hour = timestamp.hour;
    final minute = timestamp.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    return '$displayHour:$minute $period';
  }

  /// Humanized time slot with clock time (e.g. "Evening • 6:30 PM")
  String get formattedTimeWithSlot => '$timeSlot • $formattedClockTime';

  SessionModel copyWith({
    String? id,
    String? tutorId,
    String? studentId,
    DateTime? timestamp,
    String? dateString,
    String? dayOfWeek,
    String? monthYear,
    String? timeSlot,
    bool? isExtraClass,
    String? sessionType,
    SessionType? type,
    String? replacesMissedDate,
    String? notes,
  }) {
    final effectiveType = type?.toDbString() ?? sessionType ?? this.sessionType;
    return SessionModel(
      id: id ?? this.id,
      tutorId: tutorId ?? this.tutorId,
      studentId: studentId ?? this.studentId,
      timestamp: timestamp ?? this.timestamp,
      dateString: dateString ?? this.dateString,
      dayOfWeek: dayOfWeek ?? this.dayOfWeek,
      monthYear: monthYear ?? this.monthYear,
      timeSlot: timeSlot ?? this.timeSlot,
      isExtraClass: isExtraClass ?? (effectiveType != 'SCHEDULED'),
      sessionType: effectiveType,
      replacesMissedDate: replacesMissedDate ?? this.replacesMissedDate,
      notes: notes ?? this.notes,
    );
  }
}
