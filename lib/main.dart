import 'package:app_qlct/utils/notification_helper.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'config/app_theme.dart';
import 'providers/theme_provider.dart';
import 'providers/notification_provider.dart';
import 'services/notification_service.dart';
import 'screens/initial_setup/initial_screen.dart';
import 'screens/main_navigation_wrapper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Vietnamese locale for date formatting
  await initializeDateFormatting('vi_VN', null);

  // Initialize notification helpers
  await NotificationHelper.initialize();
  await NotificationService().initialize();

  // Check if InitialScreen should be shown
  final isFirstRun = await InitialScreen.shouldShowInitialScreen();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
      ],
      child: MyApp(isFirstRun: isFirstRun),
    ),
  );
}

class MyApp extends StatelessWidget {
  final bool isFirstRun;

  const MyApp({super.key, required this.isFirstRun});

  @override
  Widget build(BuildContext context) {
    // Khởi tạo notification provider khi app start
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final notificationProvider = context.read<NotificationProvider>();
      notificationProvider.initialize();
      // Kiểm tra và tạo reminder khi mở app
      notificationProvider.checkAndCreateReminders();
    });

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
