import 'package:flutter/material.dart';
import 'screens/initial_setup/initial_screen.dart';
import 'screens/main_navigation_wrapper.dart';

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
          seedColor: const Color(0xFF00A8CC), // Ocean Blue - màu xanh nước biển của cá heo
        ),
        useMaterial3: true,
      ),
      // Show InitialScreen or MainNavigationWrapper based on isFirstRun
      home: isFirstRun ? const InitialScreen() : const MainNavigationWrapper(),
      // Define named routes
      routes: {
        '/home': (context) => const MainNavigationWrapper(),
        '/initial': (context) => const InitialScreen(),
      },
      debugShowCheckedModeBanner: false, // Remove debug banner
    );
  }
}
