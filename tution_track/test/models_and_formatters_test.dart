import 'package:flutter_test/flutter_test.dart';
import 'package:tution_track/utils/formatters.dart';
import 'package:tution_track/models/student_model.dart';
import 'package:tution_track/models/session_model.dart';
import 'package:tution_track/models/payment_model.dart';

void main() {
  group('AppFormatters Tests', () {
    test('formatTaka formats correctly with currency symbol', () {
      expect(AppFormatters.formatTaka(5000), '৳ 5,000');
      expect(AppFormatters.formatTaka(0), '৳ 0');
      expect(AppFormatters.formatTaka(12500), '৳ 12,500');
    });

    test('formatDateOrdinal formats dates with correct ordinal suffix', () {
      final date1 = DateTime(2026, 9, 1);
      expect(AppFormatters.formatDateOrdinal(date1), '1st Sep, 2026');

      final date2 = DateTime(2026, 9, 2);
      expect(AppFormatters.formatDateOrdinal(date2), '2nd Sep, 2026');

      final date3 = DateTime(2026, 9, 3);
      expect(AppFormatters.formatDateOrdinal(date3), '3rd Sep, 2026');

      final date4 = DateTime(2026, 9, 4);
      expect(AppFormatters.formatDateOrdinal(date4), '4th Sep, 2026');

      final date11 = DateTime(2026, 9, 11);
      expect(AppFormatters.formatDateOrdinal(date11), '11th Sep, 2026');

      final date21 = DateTime(2026, 9, 21);
      expect(AppFormatters.formatDateOrdinal(date21), '21st Sep, 2026');
    });

    test('getTimeSlot categorizes hours according to specification', () {
      // Morning: 06:00 AM - 11:59 AM
      expect(AppFormatters.getTimeSlot(DateTime(2026, 1, 1, 8, 30)), 'Morning');

      // Noon: 12:00 PM - 03:59 PM
      expect(AppFormatters.getTimeSlot(DateTime(2026, 1, 1, 13, 0)), 'Noon');

      // Afternoon: 04:00 PM - 05:29 PM
      expect(AppFormatters.getTimeSlot(DateTime(2026, 1, 1, 16, 30)), 'Afternoon');

      // Evening: 05:30 PM - 07:29 PM
      expect(AppFormatters.getTimeSlot(DateTime(2026, 1, 1, 18, 0)), 'Evening');

      // Night: 07:30 PM onwards
      expect(AppFormatters.getTimeSlot(DateTime(2026, 1, 1, 20, 0)), 'Night');
      expect(AppFormatters.getTimeSlot(DateTime(2026, 1, 1, 2, 0)), 'Night');
    });

    test('isValidBdPhone validates strict 11-digit BD mobile numbers', () {
      expect(AppFormatters.isValidBdPhone('01712345678'), true);
      expect(AppFormatters.isValidBdPhone('01812345678'), true);
      expect(AppFormatters.isValidBdPhone('01912345678'), true);
      expect(AppFormatters.isValidBdPhone('01312345678'), true);
      expect(AppFormatters.isValidBdPhone('+8801712345678'), true);
      expect(AppFormatters.isValidBdPhone('01712-345678'), true);

      // Invalid
      expect(AppFormatters.isValidBdPhone('01212345678'), false); // 012 is invalid in BD
      expect(AppFormatters.isValidBdPhone('0171234567'), false); // 10 digits
      expect(AppFormatters.isValidBdPhone('017123456789'), false); // 12 digits
      expect(AppFormatters.isValidBdPhone('9876543210'), false);
    });
  });

  group('StudentModel & PaymentModel Serialization Tests', () {
    test('StudentModel serialization and copyWith work', () {
      final student = StudentModel(
        id: 's1',
        name: 'Tahmid',
        grade: 'Class 10',
        subjectGroup: 'Science',
        subjects: ['Physics', 'Higher Math'],
        contactNumber: '01712345678',
        studentContactNumber: '01812345678',
        monthlyFee: 5000,
        weeklySchedule: ['Sun', 'Tue', 'Thu'],
        probableTime: '16:30',
        createdAt: DateTime(2026, 1, 1),
      );

      expect(student.displaySubject, 'Physics, Higher Math');
      expect(student.formattedMonthlyFee, '৳ 5,000');
      expect(student.weeklySchedule, ['Sun', 'Tue', 'Thu']);
      expect(student.probableTime, '16:30');
      expect(student.formattedProbableTime, '04:30 PM');
      expect(student.probableTimeMinutes, 990);

      final morningStudent = student.copyWith(probableTime: '09:05');
      expect(morningStudent.formattedProbableTime, '09:05 AM');
      expect(morningStudent.probableTimeMinutes, 545);

      final map = student.toMap();
      expect(map['name'], 'Tahmid');
      expect(map['grade'], 'Class 10');
      expect(map['subjectGroup'], 'Science');
      expect(map['subjects'], ['Physics', 'Higher Math']);
      expect(map['weeklySchedule'], ['Sun', 'Tue', 'Thu']);
      expect(map['probableTime'], '16:30');

      final fromJsonStudent = StudentModel.fromJson({
        'id': 's2',
        'name': 'Taiba',
        'probableTime': '10:00',
        'weeklySchedule': ['Mon', 'Wed'],
      });
      expect(fromJsonStudent.probableTime, '10:00');
      expect(fromJsonStudent.formattedProbableTime, '10:00 AM');
      expect(fromJsonStudent.probableTimeMinutes, 600);
    });

    test('Smart schedule sorting order prioritizes pending today and sorts chronologically', () {
      final sMorning = StudentModel(
        id: 's1',
        name: 'Taiba',
        weeklySchedule: ['Fri'],
        probableTime: '10:00',
        createdAt: DateTime(2026, 1, 1),
      );
      final sAfternoon = StudentModel(
        id: 's2',
        name: 'Tahmid',
        weeklySchedule: ['Fri'],
        probableTime: '16:30',
        createdAt: DateTime(2026, 1, 1),
      );
      final sEvening = StudentModel(
        id: 's3',
        name: 'Rahim',
        weeklySchedule: ['Fri'],
        probableTime: '18:00',
        createdAt: DateTime(2026, 1, 1),
      );
      final sUnscheduled = StudentModel(
        id: 's4',
        name: 'Karim',
        weeklySchedule: ['Sat'],
        probableTime: '09:00',
        createdAt: DateTime(2026, 1, 1),
      );

      // Simulate Tahmid already marked completed today
      final completedIds = {'s2'};
      final allStudents = [sEvening, sUnscheduled, sAfternoon, sMorning];

      // Partition and sort as implemented in HomeScreen
      final bucketA = <StudentModel>[];
      final bucketB = <StudentModel>[];

      for (final s in allStudents) {
        if (completedIds.contains(s.id)) {
          bucketB.add(s);
        } else {
          bucketA.add(s);
        }
      }

      bucketA.sort((a, b) {
        final aToday = a.weeklySchedule.contains('Fri');
        final bToday = b.weeklySchedule.contains('Fri');
        if (aToday && !bToday) return -1;
        if (!aToday && bToday) return 1;

        final aTime = a.probableTimeMinutes;
        final bTime = b.probableTimeMinutes;
        if (aTime != null && bTime != null) {
          final cmp = aTime.compareTo(bTime);
          if (cmp != 0) return cmp;
        }
        return a.name.compareTo(b.name);
      });

      final result = [...bucketA, ...bucketB];

      // Expected order:
      // 1. Taiba (10:00 AM, scheduled Fri, pending)
      // 2. Rahim (18:00 / 06:00 PM, scheduled Fri, pending)
      // 3. Karim (09:00 AM, not scheduled Fri, pending)
      // 4. Tahmid (16:30, scheduled Fri, completed today)
      expect(result.map((s) => s.id).toList(), ['s1', 's3', 's4', 's2']);
    });

    test('PaymentModel serialization and formatting work', () {
      final payment = PaymentModel(
        id: 'p1',
        studentId: 's1',
        amount: 4500,
        paymentDate: DateTime(2026, 9, 4),
        period: 'August 2026',
        notes: 'bKash payment',
        createdAt: DateTime(2026, 9, 4),
      );

      expect(payment.formattedAmount, '৳ 4,500');
      expect(payment.formattedPaymentDate, '4th Sep, 2026');
      expect(payment.period, 'August 2026');

      final map = payment.toMap();
      expect(map['amount'], 4500.0);
      expect(map['period'], 'August 2026');
      expect(map['notes'], 'bKash payment');
    });

    test('SessionModel serialization and formatting work', () {
      final session = SessionModel(
        id: 'ses1',
        studentId: 's1',
        timestamp: DateTime(2026, 9, 4, 18, 30),
        dateString: '2026-09-04',
        dayOfWeek: 'Friday',
        monthYear: '2026-09',
        timeSlot: 'Evening',
        isExtraClass: true,
      );

      expect(session.formattedOrdinalDate, '4th Sep, 2026');
      expect(session.timeSlot, 'Evening');
      expect(session.isExtraClass, true);
      expect(session.formattedClockTime, '6:30 PM');
      expect(session.formattedTimeWithSlot, 'Evening • 6:30 PM');
    });
  });
}

