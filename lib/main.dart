import 'package:flutter/material.dart';
import 'screens/initial_screen.dart';
import 'screens/home_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

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
      // Set InitialScreen as the home screen
      home: const InitialScreen(),
      // Define named routes
      routes: {
        '/home': (context) => const HomePage(),
        '/initial': (context) => const InitialScreen(),
      },
      debugShowCheckedModeBanner: false, // Remove debug banner
    );
  }
}
