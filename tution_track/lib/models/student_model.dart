import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/formatters.dart';

/// Student model representing a tutor's student
class StudentModel {
  final String id;
  final String tutorId;
  final String name;
  final String grade; // e.g. "Class 10", "Inter 1st Year"
  final String subjectGroup; // Science, Commerce, Arts / Humanities, General
  final List<String> subjects; // ['Physics', 'Higher Math', etc.]
  final String subject; // Legacy fallback
  final String contactNumber; // Guardian phone (Mandatory)
  final String studentContactNumber; // Student phone (Optional)
  final String address;
  final int monthlyTargetClasses;
  final double monthlyFee;
  final bool isFeePaidThisMonth;
  final String feePaidMonthYear;
  final bool isActive;
  final List<String> weeklySchedule; // ['Sat', 'Mon', 'Wed', etc.]
  final String? _probableTime; // Standard 24h format e.g. "16:30"
  String get probableTime => (_probableTime as dynamic) ?? '';
  final DateTime? leavingDate;
  final String leavingNote;
  final DateTime createdAt;
  final List<Map<String, dynamic>>? _missedDates; // [{ 'date': '2026-09-01', 'isResolved': true, 'resolvedOn': '2026-09-03' }]
  List<Map<String, dynamic>> get missedDates => (_missedDates as dynamic) ?? const [];

  final int? _carriedForwardClasses; // Rolled over extra classes from previous cycle
  int get carriedForwardClasses => (_carriedForwardClasses as dynamic) ?? 0;

  final bool? _carryForwardExtraClasses; // Whether to auto roll-over extra classes
  bool get carryForwardExtraClasses => (_carryForwardExtraClasses as dynamic) ?? true;

  // Transient field: populated from attendance summary
  int completedSessions;

  StudentModel({
    required this.id,
    this.tutorId = '',
    required this.name,
    this.grade = '',
    this.subjectGroup = 'General',
    this.subjects = const [],
    this.subject = '',
    this.contactNumber = '',
    this.studentContactNumber = '',
    this.address = '',
    this.monthlyTargetClasses = 12,
    this.monthlyFee = 0,
    this.isFeePaidThisMonth = false,
    this.feePaidMonthYear = '',
    this.isActive = true,
    this.weeklySchedule = const [],
    String? probableTime,
    this.leavingDate,
    this.leavingNote = '',
    required this.createdAt,
    List<Map<String, dynamic>>? missedDates,
    int? carriedForwardClasses,
    bool? carryForwardExtraClasses,
    this.completedSessions = 0,
  })  : _probableTime = probableTime ?? '',
        _missedDates = missedDates ?? const [],
        _carriedForwardClasses = carriedForwardClasses ?? 0,
        _carryForwardExtraClasses = carryForwardExtraClasses ?? true;

  /// Clean specific subjects (excluding the subjectGroup to prevent duplication)
  List<String> get cleanSubjects {
    final groupLower = subjectGroup.trim().toLowerCase();
    return subjects
        .where((s) =>
            (s as dynamic) != null &&
            s.toString().trim().toLowerCase() != groupLower &&
            s.toString().trim().isNotEmpty)
        .map((s) => s.toString())
        .toList();
  }

  /// Primary subject display (joins clean subjects list or falls back to legacy field if not group name)
  String get displaySubject {
    final clean = cleanSubjects;
    if (clean.isNotEmpty) {
      return clean.join(', ');
    }
    if (subject.isNotEmpty &&
        subject.trim().toLowerCase() != subjectGroup.trim().toLowerCase()) {
      return subject;
    }
    return '';
  }

  /// Formatted monthly fee in Taka
  String get formattedMonthlyFee => AppFormatters.formatTaka(monthlyFee);

  /// Formatted 12-hour probable time string (e.g., "04:30 PM")
  String get formattedProbableTime {
    final time = probableTime;
    if (time.isEmpty) return '';
    try {
      final parts = time.split(':');
      if (parts.length >= 2) {
        final hour = int.parse(parts[0].trim());
        final minute = int.parse(parts[1].trim());
        final period = hour >= 12 ? 'PM' : 'AM';
        final h12 = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
        final mStr = minute.toString().padLeft(2, '0');
        final hStr = h12.toString().padLeft(2, '0');
        return '$hStr:$mStr $period';
      }
    } catch (_) {}
    return time;
  }

  /// Probable time in minutes from midnight (0..1439) for sorting and chronological comparison
  int? get probableTimeMinutes {
    final time = probableTime;
    if (time.isEmpty) return null;
    try {
      final parts = time.split(':');
      if (parts.length >= 2) {
        final hour = int.parse(parts[0].trim());
        final minute = int.parse(parts[1].trim());
        return hour * 60 + minute;
      }
    } catch (_) {}
    return null;
  }

  /// Total active duration in months (e.g. "5 months")
  int get activeMonthsCount {
    final endDate = leavingDate ?? DateTime.now();
    final months = (endDate.year - createdAt.year) * 12 + endDate.month - createdAt.month + 1;
    return months > 0 ? months : 1;
  }

  /// Create from a JSON map
  factory StudentModel.fromJson(Map<String, dynamic> json) {
    List<String> parseList(dynamic val) {
      if (val is List) {
        return val.where((e) => e != null).map((e) => e.toString()).toList();
      }
      return [];
    }

    List<Map<String, dynamic>> parseMapList(dynamic val) {
      if (val is List) {
        return val
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
      return [];
    }

    final parsedSubjects = parseList(json['subjects']);
    final legacySubject = json['subject']?.toString() ?? '';

    return StudentModel(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      tutorId: json['tutorId']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      grade: json['grade']?.toString() ?? '',
      subjectGroup: json['subjectGroup']?.toString() ?? 'General',
      subjects: parsedSubjects.isNotEmpty
          ? parsedSubjects
          : (legacySubject.isNotEmpty ? [legacySubject] : []),
      subject: legacySubject,
      contactNumber: json['contactNumber']?.toString() ?? '',
      studentContactNumber: json['studentContactNumber']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
      monthlyTargetClasses: json['monthlyTargetClasses'] is num
          ? (json['monthlyTargetClasses'] as num).toInt()
          : (int.tryParse(json['monthlyTargetClasses']?.toString() ?? '') ?? 12),
      monthlyFee: (json['monthlyFee'] is num ? (json['monthlyFee'] as num) : 0).toDouble(),
      isFeePaidThisMonth: json['isFeePaidThisMonth'] == true,
      feePaidMonthYear: json['feePaidMonthYear']?.toString() ?? '',
      isActive: json['isActive'] != false,
      weeklySchedule: parseList(json['weeklySchedule']),
      probableTime: json['probableTime']?.toString() ?? '',
      leavingDate: json['leavingDate'] is Timestamp
          ? (json['leavingDate'] as Timestamp).toDate()
          : (json['leavingDate'] != null
              ? DateTime.tryParse(json['leavingDate'].toString())
              : null),
      leavingNote: json['leavingNote']?.toString() ?? '',
      createdAt: json['createdAt'] != null
          ? (json['createdAt'] is Timestamp
              ? (json['createdAt'] as Timestamp).toDate()
              : DateTime.parse(json['createdAt'].toString()))
          : DateTime.now(),
      missedDates: parseMapList(json['missedDates']),
      carriedForwardClasses: json['carriedForwardClasses'] is num
          ? (json['carriedForwardClasses'] as num).toInt()
          : (int.tryParse(json['carriedForwardClasses']?.toString() ?? '') ?? 0),
      carryForwardExtraClasses: json['carryForwardExtraClasses'] != false,
      completedSessions: json['completedSessions'] is int ? json['completedSessions'] as int : 0,
    );
  }

  /// Create from a Firestore document snapshot
  factory StudentModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    List<String> parseList(dynamic val) {
      if (val is List) {
        return val.where((e) => e != null).map((e) => e.toString()).toList();
      }
      return [];
    }

    List<Map<String, dynamic>> parseMapList(dynamic val) {
      if (val is List) {
        return val
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
      return [];
    }

    final parsedSubjects = parseList(data['subjects']);
    final legacySubject = data['subject']?.toString() ?? '';

    return StudentModel(
      id: doc.id,
      tutorId: data['tutorId']?.toString() ?? '',
      name: data['name']?.toString() ?? '',
      grade: data['grade']?.toString() ?? '',
      subjectGroup: data['subjectGroup']?.toString() ?? 'General',
      subjects: parsedSubjects.isNotEmpty
          ? parsedSubjects
          : (legacySubject.isNotEmpty ? [legacySubject] : []),
      subject: legacySubject,
      contactNumber: data['contactNumber']?.toString() ?? '',
      studentContactNumber: data['studentContactNumber']?.toString() ?? '',
      address: data['address']?.toString() ?? '',
      monthlyTargetClasses: data['monthlyTargetClasses'] is num
          ? (data['monthlyTargetClasses'] as num).toInt()
          : (int.tryParse(data['monthlyTargetClasses']?.toString() ?? '') ?? 12),
      monthlyFee: (data['monthlyFee'] is num ? (data['monthlyFee'] as num) : 0).toDouble(),
      isFeePaidThisMonth: data['isFeePaidThisMonth'] == true,
      feePaidMonthYear: data['feePaidMonthYear']?.toString() ?? '',
      isActive: data['isActive'] != false,
      weeklySchedule: parseList(data['weeklySchedule']),
      probableTime: data['probableTime']?.toString() ?? '',
      leavingDate: data['leavingDate'] is Timestamp
          ? (data['leavingDate'] as Timestamp).toDate()
          : (data['leavingDate'] != null
              ? DateTime.tryParse(data['leavingDate'].toString())
              : null),
      leavingNote: data['leavingNote']?.toString() ?? '',
      createdAt: data['createdAt'] is Timestamp
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      missedDates: parseMapList(data['missedDates']),
      carriedForwardClasses: data['carriedForwardClasses'] is num
          ? (data['carriedForwardClasses'] as num).toInt()
          : 0,
      carryForwardExtraClasses: data['carryForwardExtraClasses'] != false,
      completedSessions: data['completedSessions'] is int ? data['completedSessions'] as int : 0,
    );
  }

  /// Convert to Firestore map
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'grade': grade,
      'subjectGroup': subjectGroup,
      'subjects': subjects,
      'subject': displaySubject,
      'contactNumber': contactNumber,
      'studentContactNumber': studentContactNumber,
      'address': address,
      'monthlyTargetClasses': monthlyTargetClasses,
      'monthlyFee': monthlyFee,
      'isFeePaidThisMonth': isFeePaidThisMonth,
      'feePaidMonthYear': feePaidMonthYear,
      'isActive': isActive,
      'weeklySchedule': weeklySchedule,
      'probableTime': probableTime,
      'leavingDate': leavingDate != null ? Timestamp.fromDate(leavingDate!) : null,
      'leavingNote': leavingNote,
      'createdAt': Timestamp.fromDate(createdAt),
      'missedDates': missedDates,
      'carriedForwardClasses': carriedForwardClasses,
      'carryForwardExtraClasses': carryForwardExtraClasses,
    };
  }

  Map<String, dynamic> toJson() => toMap();

  /// Progress ratio (0.0 to 1.0+)
  double get progressRatio {
    if (monthlyTargetClasses == 0) return 0;
    return completedSessions / monthlyTargetClasses;
  }

  /// Whether quota is met or exceeded
  bool get isQuotaMet => completedSessions >= monthlyTargetClasses;

  /// Extra classes beyond quota
  int get extraClasses {
    final extra = completedSessions - monthlyTargetClasses;
    return extra > 0 ? extra : 0;
  }

  /// Progress display text
  String get progressText => '$completedSessions / $monthlyTargetClasses';

  /// Formatted progress text with extra class indicator e.g. "17 / 16 (+1 Extra)"
  String formattedProgressWithExtra([int extraBonus = 0]) {
    if (extraBonus > 0) {
      return '$completedSessions / $monthlyTargetClasses (+$extraBonus Extra)';
    }
    return progressText;
  }

  StudentModel copyWith({
    String? id,
    String? tutorId,
    String? name,
    String? grade,
    String? subjectGroup,
    List<String>? subjects,
    String? subject,
    String? contactNumber,
    String? studentContactNumber,
    String? address,
    int? monthlyTargetClasses,
    double? monthlyFee,
    bool? isFeePaidThisMonth,
    String? feePaidMonthYear,
    bool? isActive,
    List<String>? weeklySchedule,
    String? probableTime,
    DateTime? leavingDate,
    String? leavingNote,
    DateTime? createdAt,
    List<Map<String, dynamic>>? missedDates,
    int? carriedForwardClasses,
    bool? carryForwardExtraClasses,
    int? completedSessions,
  }) {
    return StudentModel(
      id: id ?? this.id,
      tutorId: tutorId ?? this.tutorId,
      name: name ?? this.name,
      grade: grade ?? this.grade,
      subjectGroup: subjectGroup ?? this.subjectGroup,
      subjects: subjects ?? this.subjects,
      subject: subject ?? this.subject,
      contactNumber: contactNumber ?? this.contactNumber,
      studentContactNumber: studentContactNumber ?? this.studentContactNumber,
      address: address ?? this.address,
      monthlyTargetClasses: monthlyTargetClasses ?? this.monthlyTargetClasses,
      monthlyFee: monthlyFee ?? this.monthlyFee,
      isFeePaidThisMonth: isFeePaidThisMonth ?? this.isFeePaidThisMonth,
      feePaidMonthYear: feePaidMonthYear ?? this.feePaidMonthYear,
      isActive: isActive ?? this.isActive,
      weeklySchedule: weeklySchedule ?? this.weeklySchedule,
      probableTime: probableTime ?? this.probableTime,
      leavingDate: leavingDate ?? this.leavingDate,
      leavingNote: leavingNote ?? this.leavingNote,
      createdAt: createdAt ?? this.createdAt,
      missedDates: missedDates ?? this.missedDates,
      carriedForwardClasses: carriedForwardClasses ?? this.carriedForwardClasses,
      carryForwardExtraClasses: carryForwardExtraClasses ?? this.carryForwardExtraClasses,
      completedSessions: completedSessions ?? this.completedSessions,
    );
  }
}
