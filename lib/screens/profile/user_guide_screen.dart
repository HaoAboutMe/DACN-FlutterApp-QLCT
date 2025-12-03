import 'package:app_qlct/screens/home/home_colors.dart';
import 'package:flutter/material.dart';

/// Màn hình Hướng dẫn sử dụng - Hướng dẫn người dùng cách sử dụng Whales Spent
class UserGuideScreen extends StatelessWidget {
  const UserGuideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'Hướng dẫn sử dụng',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        foregroundColor: colorScheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            _buildHeader(isDark, colorScheme),

            const SizedBox(height: 24),

            // Section 1: Khởi tạo ban đầu
            _buildSection1(isDark, colorScheme),

            const SizedBox(height: 20),

            // Section 2: Quản lý giao dịch
            _buildSection2(isDark, colorScheme),

            const SizedBox(height: 20),

            // Section 3: Quản lý khoản vay
            _buildSection3(isDark, colorScheme),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF5D5FEF).withValues(alpha: 0.1),
            const Color(0xFF5D5FEF).withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF5D5FEF).withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF5D5FEF).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.help_outline_rounded,
              color: Color(0xFF5D5FEF),
              size: 32,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hướng dẫn sử dụng Whales Spent',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Dưới đây là hướng dẫn cơ bản để bạn bắt đầu sử dụng ứng dụng một cách dễ dàng và chính xác nhất.',
                  style: TextStyle(
                    fontSize: 13,
                    color: colorScheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection1(bool isDark, ColorScheme colorScheme) {
    return _buildSectionCard(
      isDark: isDark,
      colorScheme: colorScheme,
      icon: Icons.play_circle_outline,
      iconColor: Colors.blue,
      title: '1. Khởi tạo ban đầu',
      description: 'Khi mở ứng dụng lần đầu, bạn sẽ trải qua bốn bước thiết lập nhanh:',
      steps: [
        {'text': 'Nhập tên người dùng của bạn.'},
        {'text': 'Chọn loại tiền tệ mà bạn muốn (VND, USD).'},
        {'text': 'Nhập số dư hiện tại mà bạn đang có.'},
        {'text': 'Xác nhận lại tên, loại tiền và số dư. Sau khi hoàn tất, bạn có thể bắt đầu sử dụng Whales Spent.'},
      ],
      note: {
        'icon': Icons.lightbulb_outline,
        'text': 'Bạn không cần tính toán lại toàn bộ thu – chi ban đầu. Chỉ cần nhập đúng số tiền thực tế bạn đang có tại thời điểm bắt đầu sử dụng ứng dụng.',
      },
    );
  }

  Widget _buildSection2(bool isDark, ColorScheme colorScheme) {
    return _buildSectionCard(
      isDark: isDark,
      colorScheme: colorScheme,
      icon: Icons.receipt_long,
      iconColor: Colors.green,
      title: '2. Quản lý giao dịch (Thu nhập / Chi tiêu)',
      steps: [
        {'text': 'Chọn "Thu nhập" hoặc "Chi tiêu" ở thanh thao tác nhanh.'},
        {'text': 'Nhập số tiền giao dịch.'},
        {'text': 'Nhập mô tả (Ví dụ: "Ăn sáng cơm tấm").'},
        {
          'text': 'Chọn danh mục phù hợp.',
          'sub': [
            'Danh mục sẽ thay đổi tùy theo bạn đang thêm thu nhập hay chi tiêu.',
            'Bạn có thể tạo danh mục mới theo nhu cầu bằng cách chọn "Thêm danh mục mới".',
          ],
        },
        {'text': 'Chọn ngày giao dịch (mặc định là ngày hiện tại).'},
        {'text': 'Lưu giao dịch.'},
        {'text': 'Kiểm tra lại giao dịch vừa tạo tại trang "Giao dịch" hoặc ngay trong trang chủ.'},
      ],
      notes: [
        {
          'icon': Icons.trending_up,
          'iconColor': HomeColors.income,
          'text': 'Giao dịch "Thu nhập" sẽ cộng vào số dư hiện tại.',
        },
        {
          'icon': Icons.trending_down,
          'iconColor': HomeColors.expense,
          'text': 'Giao dịch "Chi tiêu" sẽ trừ vào số dư hiện tại.',
        },
        {
          'icon': Icons.edit_outlined,
          'text': 'Bạn có thể chỉnh sửa hoặc xóa giao dịch bất cứ lúc nào và số dư sẽ được cập nhật theo thay đổi của bạn.',
        },
      ],
    );
  }

  Widget _buildSection3(bool isDark, ColorScheme colorScheme) {
    return _buildSectionCard(
      isDark: isDark,
      colorScheme: colorScheme,
      icon: Icons.account_balance_wallet,
      iconColor: Colors.orange,
      title: '3. Quản lý khoản vay (Cho vay / Đi vay)',
      steps: [
        {'text': 'Chọn "Cho vay" hoặc "Đi vay" ở thanh thao tác nhanh.'},
        {'text': 'Nhập tên người liên quan đến khoản vay.'},
        {'text': 'Nhập số tiền cho vay hoặc đi vay.'},
        {'text': 'Nhập số điện thoại (không bắt buộc).'},
        {'text': 'Nhập mô tả nếu cần (không bắt buộc).'},
        {'text': 'Chọn ngày đáo hạn của khoản vay (có thể để trống nếu không xác định).'},
        {'text': 'Bật hoặc tắt thông báo nhắc nhở.'},
        {
          'text': 'Chọn loại khoản vay:',
          'sub': [
            'MỚI: Các khoản phát sinh sau khi bạn sử dụng Whales Spent. Ảnh hưởng đến số dư hiện tại.',
            'CŨ: Các khoản tồn tại trước khi sử dụng ứng dụng. Không ảnh hưởng đến số dư hiện tại.',
          ],
        },
        {'text': 'Lưu khoản vay.'},
        {'text': 'Kiểm tra khoản vay trong trang "Cho vay" hoặc tại trang chủ.'},
      ],
      explanation: {
        'icon': Icons.info_outline,
        'text': 'Bạn không cần tự tính toán lại khoản vay từ trước. Chỉ cần chọn đúng loại (MỚI hoặc CŨ), Whales Spent sẽ tự xử lý phần còn lại.',
      },
      notes: [
        {
          'icon': Icons.call_received,
          'iconColor': HomeColors.loanReceived,
          'text': '"Đi vay" sẽ cộng tiền vào số dư hiện tại.',
        },
        {
          'icon': Icons.call_made,
          'iconColor': HomeColors.loanGiven,
          'text': '"Cho vay" sẽ trừ tiền khỏi số dư hiện tại.',
        },
        {
          'icon': Icons.receipt,
          'text': 'Các khoản vay MỚI sẽ tự động tạo 1 giao dịch kèm theo để thể hiện việc số dư đã thay đổi.',
        },
        {
          'icon': Icons.history,
          'text': 'Các khoản vay CŨ sẽ không tạo giao dịch và không ảnh hưởng số dư.',
        },
        {
          'icon': Icons.payments_outlined,
          'text': 'Trong trang "Cho vay", bạn có thể sử dụng chức năng Thu nợ / Trả nợ khi khoản vay đến hạn.',
        },
        {
          'icon': Icons.lock_outline,
          'iconColor': Colors.orange,
          'text': 'Các khoản vay đã đánh dấu "Đã thanh toán" sẽ không thể chỉnh sửa hoặc xóa nhằm giữ lại lịch sử chính xác.',
        },
      ],
    );
  }

  Widget _buildSectionCard({
    required bool isDark,
    required ColorScheme colorScheme,
    required IconData icon,
    required Color iconColor,
    required String title,
    String? description,
    required List<Map<String, dynamic>> steps,
    Map<String, dynamic>? note,
    Map<String, dynamic>? explanation,
    List<Map<String, dynamic>>? notes,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: iconColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),

          if (description != null) ...[
            const SizedBox(height: 12),
            Text(
              description,
              style: TextStyle(
                fontSize: 14,
                color: colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
          ],

          const SizedBox(height: 16),

          // Steps
          ...steps.asMap().entries.map((entry) {
            final index = entry.key;
            final step = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        margin: const EdgeInsets.only(top: 2),
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF5D5FEF).withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '${index + 1}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF5D5FEF),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          step['text'] as String,
                          style: TextStyle(
                            fontSize: 14,
                            color: colorScheme.onSurface,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (step['sub'] != null) ...[
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.only(left: 36),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: (step['sub'] as List<String>).map((subText) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  margin: const EdgeInsets.only(top: 6),
                                  width: 4,
                                  height: 4,
                                  decoration: BoxDecoration(
                                    color: colorScheme.onSurfaceVariant,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    subText,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: colorScheme.onSurfaceVariant,
                                      height: 1.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ],
              ),
            );
          }),

          // Single Note
          if (note != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.amber.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    note['icon'] as IconData,
                    color: Colors.amber[700],
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      note['text'] as String,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.amber[300] : Colors.amber[900],
                        height: 1.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Explanation
          if (explanation != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.blue.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    explanation['icon'] as IconData,
                    color: Colors.blue,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      explanation['text'] as String,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.blue[300] : Colors.blue[900],
                        height: 1.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Multiple Notes
          if (notes != null && notes.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.notes,
                        size: 18,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Ghi chú:',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ...notes.map((noteItem) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            noteItem['icon'] as IconData,
                            color: noteItem['iconColor'] as Color? ?? colorScheme.primary,
                            size: 18,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              noteItem['text'] as String,
                              style: TextStyle(
                                fontSize: 13,
                                color: colorScheme.onSurfaceVariant,
                                height: 1.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

