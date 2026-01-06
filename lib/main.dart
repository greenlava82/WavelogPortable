import 'package:flutter/material.dart';
import 'config/theme.dart';
import 'screens/input_screen.dart';

void main() {
  runApp(const WavelogPortable());
}

class WavelogPortable extends StatelessWidget {
  const WavelogPortable({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Wavelog Portable',
      theme: ThemeData(
        useMaterial3: true,
        primaryColor: AppTheme.primaryColor,
        scaffoldBackgroundColor: AppTheme.backgroundColor,
        colorScheme: ColorScheme.fromSeed(seedColor: AppTheme.primaryColor),
      ),
      home: const CallsignInputScreen(),
    );
  }
}