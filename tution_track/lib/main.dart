import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'providers/theme_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/student_provider.dart';
import 'providers/attendance_provider.dart';
import 'providers/payment_provider.dart';
import 'services/connectivity_service.dart';
import 'screens/splash_screen.dart';
import 'authentication/screens/login_screen.dart';
import 'authentication/screens/register_screen.dart';
import 'authentication/screens/forgot_password_screen.dart';
import 'authentication/screens/reset_password_screen.dart';
import 'authentication/screens/verify_email_screen.dart';
import 'screens/home_screen.dart';
import 'screens/student_form_screen.dart';
import 'screens/student_detail_screen.dart';
import 'screens/settings_screen.dart';
import 'utils/constants.dart';
import 'utils/theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp();

  // Configure Firestore offline persistence & cache size (100 MB)
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: 104857600, // 100 MB
  );

  // Set preferred orientation
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Set system UI overlay style
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    systemNavigationBarColor: AppTheme.cardWhite,
    systemNavigationBarIconBrightness: Brightness.dark,
  ));

  runApp(const TutionTrackApp());
}

class TutionTrackApp extends StatelessWidget {
  const TutionTrackApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(375, 812), // iPhone X baseline
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        return MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => ThemeProvider()),
            ChangeNotifierProvider(create: (_) => AuthProvider()),
            ChangeNotifierProvider(create: (_) => StudentProvider()),
            ChangeNotifierProvider(create: (_) => AttendanceProvider()),
            ChangeNotifierProvider(create: (_) => PaymentProvider()),
            ChangeNotifierProvider(create: (_) => ConnectivityService()),
          ],
          child: Consumer<ThemeProvider>(
            builder: (context, themeProvider, _) {
              return MaterialApp(
                title: AppConstants.appName,
                debugShowCheckedModeBanner: false,
                theme: themeProvider.lightTheme,
                darkTheme: themeProvider.darkTheme,
                themeMode: themeProvider.themeMode,

                // Initial route
                initialRoute: Routes.splash,

            // Named routes
            routes: {
              Routes.splash: (_) => const SplashScreen(),
              Routes.login: (_) => const AuthLoginScreen(),
              Routes.register: (_) => const AuthRegisterScreen(),
              Routes.forgotPassword: (_) => const AuthForgotPasswordScreen(),
              Routes.resetPassword: (_) => const ResetPasswordScreen(),
              Routes.verifyEmail: (_) => const VerifyEmailScreen(),
              Routes.home: (_) => const HomeScreen(),
              Routes.addStudent: (_) => const StudentFormScreen(),
              Routes.editStudent: (_) => const StudentFormScreen(),
              Routes.studentDetail: (_) => const StudentDetailScreen(),
              Routes.settings: (_) => const SettingsScreen(),
            },
          );
        },
      ),
    );
  },
);
  }
}

