/// App-wide constants and route names
class AppConstants {
  AppConstants._();

  // App Info
  static const String appName = 'TutionTrack';
  static const String appVersion = '1.5.2';
  static const String appDeveloper = 'Sic Mundus';
  static const String appTagline = 'Smart Tution Management';

  // Default Values
  static const int defaultMonthlyTarget = 12;
  static const double defaultMonthlyFee = 0;

  // Days of Week
  static const List<String> daysOfWeek = [
    'Sunday', 'Monday', 'Tuesday', 'Wednesday',
    'Thursday', 'Friday', 'Saturday',
  ];
}

/// Named Route Paths
class Routes {
  Routes._();

  static const String splash = '/';
  static const String login = '/login';
  static const String register = '/register';
  static const String forgotPassword = '/forgot-password';
  static const String resetPassword = '/reset-password';
  static const String verifyEmail = '/verify-email';
  static const String home = '/home';
  static const String addStudent = '/add-student';
  static const String editStudent = '/edit-student';
  static const String studentDetail = '/student-detail';
  static const String attendanceHistory = '/attendance-history';
  static const String settings = '/settings';
}
