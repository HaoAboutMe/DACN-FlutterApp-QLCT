import 'package:flutter/material.dart';

/// Màn hình Thống kê - Placeholder cho tương lai
class StatisticsScreen extends StatelessWidget {
  const StatisticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icon cá voi với biểu đồ
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF00A8CC).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.insert_chart_outlined_rounded,
                size: 80,
                color: Color(0xFF00A8CC),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Thống kê',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Color(0xFF00A8CC),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Tính năng đang được phát triển...',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '🐋 Coming soon!',
              style: TextStyle(
                fontSize: 24,
                color: Colors.grey.shade400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
