import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/initial_setup/initial_screen.dart';
import 'screens/home/home_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Check if InitialScreen should be shown
  final isFirstRun = await InitialScreen.shouldShowInitialScreen();

  runApp(MyApp(isFirstRun: isFirstRun));
}

class MyApp extends StatelessWidget {
  final bool isFirstRun;

  const MyApp({super.key, required this.isFirstRun});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Whales Spent',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1E88E5), // Primary blue color
        ),
        useMaterial3: true,
      ),
      // Show InitialScreen or HomePage based on isFirstRun
      home: isFirstRun ? const InitialScreen() : const HomePage(),
      // Define named routes
      routes: {
        '/home': (context) => const HomePage(),
        '/initial': (context) => const InitialScreen(),
      },
      debugShowCheckedModeBanner: false, // Remove debug banner
    );
  }
}
