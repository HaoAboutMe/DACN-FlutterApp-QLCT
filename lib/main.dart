import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'config/app_theme.dart';
import 'providers/theme_provider.dart';
import 'screens/initial_setup/initial_screen.dart';
import 'screens/main_navigation_wrapper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Check if InitialScreen should be shown
  final isFirstRun = await InitialScreen.shouldShowInitialScreen();

  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: MyApp(isFirstRun: isFirstRun),
    ),
  );
}

class MyApp extends StatelessWidget {
  final bool isFirstRun;

  const MyApp({super.key, required this.isFirstRun});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          title: 'Whales Spent',
          // Sử dụng theme tùy chỉnh
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeProvider.themeMode,
          // Show InitialScreen or MainNavigationWrapper based on isFirstRun
          home: isFirstRun ? const InitialScreen() : MainNavigationWrapper(key: mainNavigationKey),
          // Define named routes
          routes: {
            '/home': (context) => MainNavigationWrapper(key: mainNavigationKey),
            '/initial': (context) => const InitialScreen(),
          },
          debugShowCheckedModeBanner: false, // Remove debug banner
        );
      },
    );
  }
}