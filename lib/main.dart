import 'package:flutter/material.dart';
import 'package:app_chat/theme/app_theme.dart';
import 'package:app_chat/screens/splash_screen.dart';
import 'package:app_chat/screens/auth_screen.dart';
import 'package:app_chat/screens/home_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const KonvoApp());
}

class KonvoApp extends StatelessWidget {
  const KonvoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Konvo',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.dark,
      debugShowCheckedModeBanner: false,

      // 👇 SplashScreen ALWAYS first
      home: const SplashScreen(),
    );
  }
}
