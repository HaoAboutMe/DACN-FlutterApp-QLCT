import 'package:app_qlct/utils/notification_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'config/app_theme.dart';
import 'providers/theme_provider.dart';
import 'providers/notification_provider.dart';
import 'providers/currency_provider.dart';
import 'services/notification_service.dart';
import 'services/widget_service.dart';
import 'database/database_helper.dart';
import 'screens/initial_setup/initial_screen.dart';
import 'screens/main_navigation_wrapper.dart';
import 'utils/currency_formatter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Vietnamese locale for date formatting
  await initializeDateFormatting('vi_VN', null);

  // Initialize notification helpers
  await NotificationHelper.initialize();

  // ✅ KHỞI TẠO NOTIFICATION SERVICE VỚI WORKMANAGER
  final notificationService = NotificationService();
  await notificationService.initialize();

  // ✅ CHECK LOAN REMINDERS KHI APP MỞ
  try {
    await notificationService.checkAndCreateLoanReminders();
    debugPrint('✅ Loan reminders checked on startup');
  } catch (e) {
    debugPrint('❌ Error checking loan reminders: $e');
  }

  // Initialize default categories if database is empty
  try {
    final databaseHelper = DatabaseHelper();
    await databaseHelper.insertDefaultCategoriesIfNeeded();
  } catch (e) {
    debugPrint('Error initializing default categories: $e');
  }

  // ✅ CẬP NHẬT WIDGET KHI APP MỞ
  try {
    debugPrint('🔄 Updating home screen widget...');
    await WidgetService.updateWidgetData();
  } catch (e) {
    debugPrint('❌ Error updating widget on startup: $e');
  }

  // Setup MethodChannel để nhận intent từ widget
  setupWidgetChannel();

  // Check if InitialScreen should be shown
  final isFirstRun = await InitialScreen.shouldShowInitialScreen();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
        ChangeNotifierProvider(
          create: (_) {
            final provider = CurrencyProvider();
            CurrencyFormatter.setCurrencyProvider(provider);
            return provider;
          },
        ),
      ],
      child: MyApp(isFirstRun: isFirstRun),
    ),
  );
}

/// Setup MethodChannel để nhận message từ Android widget
void setupWidgetChannel() {
  const channel = MethodChannel('com.example.app_qlct/widget');

  channel.setMethodCallHandler((call) async {
    if (call.method == 'openTab') {
      final int tabIndex = call.arguments as int;
      debugPrint('📱 Widget clicked - Opening tab $tabIndex');

      final navState = mainNavigationKey.currentState;
      if (navState != null) {
        navState.switchToTab(tabIndex);
      } else {
        pendingWidgetTabNotifier.value = tabIndex;
      }
    }
  });
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
          home: isFirstRun
              ? const InitialScreen()
              : MainNavigationWrapper(
            key: mainNavigationKey,
            initialIndex: pendingWidgetTabNotifier.value ?? 0,
          ),
          // Define named routes
          routes: {
            '/home': (context) => MainNavigationWrapper(
              key: mainNavigationKey,
              initialIndex: pendingWidgetTabNotifier.value ?? 0,
            ),
            '/initial': (context) => const InitialScreen(),
          },
          debugShowCheckedModeBanner: false, // Remove debug banner
        );
      },
    );
  }
}
