import 'package:flutter/material.dart';
import '../../../utils/notification_helper.dart';

class ProfileReminderDialog {
  static void show({
    required BuildContext context,
    required bool reminderEnabled,
    required TimeOfDay reminderTime,
    required Function(bool, TimeOfDay) onSave,
    required VoidCallback onRequestPermission,
  }) {
    bool tempEnabled = reminderEnabled;
    TimeOfDay tempTime = reminderTime;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: const Text('Cài đặt nhắc nhở hằng ngày'),
          content: StatefulBuilder(
            builder: (context, setStateDialog) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Bật nhắc nhở'),
                      Switch(
                        value: tempEnabled,
                        onChanged: (value) {
                          setStateDialog(() => tempEnabled = value);
                        },
                        activeTrackColor: const Color(0xFF5D5FEF),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Thời gian'),
                      TextButton.icon(
                        onPressed: () async {
                          final picked = await showTimePicker(
                            context: context,
                            initialTime: tempTime,
                          );
                          if (picked != null) {
                            setStateDialog(() => tempTime = picked);
                          }
                        },
                        icon: const Icon(Icons.access_time, size: 18),
                        label: Text(
                          '${tempTime.hour.toString().padLeft(2, '0')}:${tempTime.minute.toString().padLeft(2, '0')}',
                          style: const TextStyle(fontSize: 15),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Test notification button
                  OutlinedButton.icon(
                    onPressed: () async {
                      await NotificationHelper.showInstantNotification(
                        title: '🐋 Whales Spent Test',
                        body: 'Thông báo đang hoạt động tốt! Bây giờ là ${TimeOfDay.now().hour}:${TimeOfDay.now().minute.toString().padLeft(2, '0')}',
                      );
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Đã gửi thông báo test!'),
                            backgroundColor: Color(0xFF5D5FEF),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.notifications_active, size: 18),
                    label: const Text('Test thông báo ngay'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF5D5FEF),
                      side: const BorderSide(color: Color(0xFF5D5FEF)),
                    ),
                  ),
                ],
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (tempEnabled) {
                  // Check permission first
                  final hasPermission = await NotificationHelper.checkExactAlarmPermission();

                  if (!hasPermission) {
                    if (context.mounted) {
                      Navigator.pop(context);
                      onRequestPermission();
                    }
                    return;
                  }

                  await NotificationHelper.scheduleDailyNotification(
                    hour: tempTime.hour,
                    minute: tempTime.minute,
                  );
                } else {
                  await NotificationHelper.cancelDailyNotification();
                }

                onSave(tempEnabled, tempTime);

                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(tempEnabled
                          ? 'Đã bật nhắc nhở lúc ${tempTime.hour.toString().padLeft(2, '0')}:${tempTime.minute.toString().padLeft(2, '0')}'
                          : 'Đã tắt nhắc nhở hằng ngày'),
                      backgroundColor: const Color(0xFF5D5FEF),
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF5D5FEF),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Lưu', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }
}

