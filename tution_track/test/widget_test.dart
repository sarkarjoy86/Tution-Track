import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tution_track/models/session_model.dart';
import 'package:tution_track/models/student_model.dart';
import 'package:tution_track/widgets/session_tile.dart';
import 'package:tution_track/widgets/next_tution_banner.dart';

void main() {
  testWidgets('SessionTile renders time slot, ordinal date, and extra class badge',
      (WidgetTester tester) async {
    final session = SessionModel(
      id: 'test_id',
      studentId: 'stud_1',
      timestamp: DateTime(2026, 9, 4, 18, 30),
      dateString: '2026-09-04',
      dayOfWeek: 'Friday',
      monthYear: '2026-09',
      timeSlot: 'Evening',
      isExtraClass: true,
      notes: 'Revision session',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SessionTile(
            session: session,
            classNumber: 1,
          ),
        ),
      ),
    );

    // Verify SessionTile displays formatted ordinal date, class number, day initial, time slot, and bonus extra class badge
    expect(find.text('#01'), findsOneWidget);
    expect(find.text('FRI'), findsOneWidget);
    expect(find.text('4th Sep, 2026'), findsOneWidget);
    expect(find.textContaining('Evening'), findsOneWidget);
    expect(find.text('Bonus Extra Class'), findsOneWidget);
    expect(find.text('Revision session'), findsOneWidget);
  });

  testWidgets('SessionTile renders Makeup Class badge with subtitle note',
      (WidgetTester tester) async {
    final makeupSession = SessionModel(
      id: 'test_id_makeup',
      studentId: 'stud_1',
      timestamp: DateTime(2026, 9, 3, 16, 30),
      dateString: '2026-09-03',
      dayOfWeek: 'Thursday',
      monthYear: '2026-09',
      sessionType: 'MAKEUP',
      replacesMissedDate: '2026-09-01',
      notes: 'Trigonometry',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SessionTile(
            session: makeupSession,
            classNumber: 2,
          ),
        ),
      ),
    );

    expect(find.text('#02'), findsOneWidget);
    expect(find.text('THU'), findsOneWidget);
    expect(find.text('Makeup Class'), findsOneWidget);
    expect(find.text('↩ Replaces Missed: Tue, 1st Sep'), findsOneWidget);
  });

  testWidgets('NextTutionBanner renders correctly across all 3 states without null errors',
      (WidgetTester tester) async {
    final student = StudentModel(
      id: 'stud_1',
      name: 'Taiba',
      address: 'Dhanmondi 27',
      weeklySchedule: ['Sat'],
      probableTime: '16:30',
      createdAt: DateTime.now(),
    );

    // State 1: Upcoming Today
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NextTutionBanner(
            nextStudent: student,
            hasScheduledToday: true,
            allCompletedToday: false,
            tomorrowSummary: 'Tomorrow: Rahim at 10:00 AM',
          ),
        ),
      ),
    );
    expect(find.text('Next: Taiba'), findsOneWidget);
    expect(find.text(' • Today, 04:30 PM'), findsOneWidget);
    expect(find.text('Dhanmondi 27'), findsOneWidget);

    // State 1b: Upcoming Tomorrow
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NextTutionBanner(
            nextStudent: student,
            hasScheduledToday: false,
            allCompletedToday: false,
            isTomorrow: true,
          ),
        ),
      ),
    );
    expect(find.text('Next: Taiba'), findsOneWidget);
    expect(find.text(' • Tomorrow, 04:30 PM'), findsOneWidget);

    // State 2: All Completed Today
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: NextTutionBanner(
            hasScheduledToday: true,
            allCompletedToday: true,
            tomorrowSummary: "Tomorrow's first class: Taiba at 10:00 AM",
          ),
        ),
      ),
    );
    expect(find.text('All done for today! 🎉'), findsOneWidget);
    expect(find.text("Tomorrow's first class: Taiba at 10:00 AM"), findsOneWidget);

    // State 3: No Classes Scheduled
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: NextTutionBanner(
            hasScheduledToday: false,
            allCompletedToday: false,
          ),
        ),
      ),
    );
    expect(find.text('No classes scheduled for today. Take rest!'), findsOneWidget);
  });
}

