import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../services/widget_service.dart';

class ProfileWidgetDialogs {
  static const MethodChannel _widgetChannel = MethodChannel('com.example.app_qlct/widget');

  /// Show add widget dialog
  static Future<void> showAddWidgetDialog({
    required BuildContext context,
    required bool isWidgetPinned,
    required bool supportsAndroidWidget,
    required Function(bool) onPinStatusChanged,
  }) async {
    if (!supportsAndroidWidget) {
      showManualWidgetGuide(context);
      return;
    }

    final bool? shouldAdd = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Thêm widget Whales Spent'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isWidgetPinned
                    ? 'Widget đã có trên màn hình chính. Bạn có thể làm mới dữ liệu bất cứ lúc nào.'
                    : 'Widget giúp xem nhanh thu chi, khoản vay và danh mục nổi bật ngay từ màn hình chính.',
              ),
              const SizedBox(height: 16),
              _buildInstructionRow('1', 'Nhấn Giữ màn hình chính → chọn Widgets.'),
              _buildInstructionRow('2', 'Chọn Whales Spent và kéo widget ra màn hình.'),
              _buildInstructionRow('3', 'Chạm vào widget để mở nhanh thống kê trong ứng dụng.'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Để sau'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF5D5FEF),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text(isWidgetPinned ? 'Cập nhật widget' : 'Thêm ngay'),
            ),
          ],
        );
      },
    );

    if (shouldAdd == true && context.mounted) {
      await requestWidgetPin(context, onPinStatusChanged);
    }
  }

  /// Request widget pin
  static Future<void> requestWidgetPin(
    BuildContext context,
    Function(bool) onPinStatusChanged,
  ) async {
    try {
      await WidgetService.updateWidgetData();
      final bool? result = await _widgetChannel.invokeMethod<bool>('requestPinWidget');

      if (!context.mounted) return;

      if (result == true) {
        // Poll widget status
        bool pinned = false;
        for (int i = 0; i < 5; i++) {
          await Future.delayed(const Duration(seconds: 1));
          pinned = await _widgetChannel.invokeMethod<bool>('hasPinnedWidget') ?? false;
          if (pinned) break;
        }

        if (!context.mounted) return;
        onPinStatusChanged(pinned);
      } else {
        showManualWidgetGuide(context);
      }
    } on PlatformException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Không thể thêm widget: ${e.message ?? e.code}'),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Có lỗi xảy ra: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Check widget pin status
  static Future<bool> checkWidgetPinStatus() async {
    try {
      final bool? isPinned = await _widgetChannel.invokeMethod<bool>('hasPinnedWidget');
      return isPinned ?? false;
    } catch (e) {
      debugPrint('Không thể kiểm tra trạng thái widget: $e');
      return false;
    }
  }

  /// Show manual widget guide
  static void showManualWidgetGuide(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Thêm widget thủ công'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Nếu thiết bị không hỗ trợ tự động, hãy làm theo các bước sau:'),
            SizedBox(height: 12),
            Text('1. Về màn hình chính và nhấn giữ vào vùng trống.'),
            Text('2. Chọn Widgets → tìm Whales Spent.'),
            Text('3. Kéo widget ra màn hình và thả.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Đã hiểu'),
          ),
        ],
      ),
    );
  }

  /// Show exact alarm permission dialog
  static void showExactAlarmPermissionDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
            SizedBox(width: 8),
            Text('Cần cấp quyền'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Để thông báo hằng ngày hoạt động, bạn cần cấp quyền "Alarms & reminders" cho ứng dụng.',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF5D5FEF).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF5D5FEF).withValues(alpha: 0.3)),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Hướng dẫn:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  SizedBox(height: 8),
                  Text('1. Vào Settings → Apps', style: TextStyle(fontSize: 12)),
                  Text('2. Chọn Whales Spent', style: TextStyle(fontSize: 12)),
                  Text('3. Tìm "Special app access"', style: TextStyle(fontSize: 12)),
                  Text('4. Chọn "Alarms & reminders"', style: TextStyle(fontSize: 12)),
                  Text('5. Bật quyền cho Whales Spent', style: TextStyle(fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }

  static Widget _buildInstructionRow(String step, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFF5D5FEF).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              step,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF5D5FEF),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              description,
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

