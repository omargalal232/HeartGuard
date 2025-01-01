//import './common/constants.dart';
import 'views/onboarding_screen.dart';
import './styles/theme.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false, // Removes the debug banner
      title: "Heart Guard",
      theme: theme,
      home: const OnboardingScreen(),
    );
  }
}
