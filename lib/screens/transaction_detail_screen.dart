import 'package:flutter/material.dart';
import '../models/transaction.dart';

class TransactionDetailScreen extends StatelessWidget {
  final Transaction transaction;
  final VoidCallback? onEdit;

  const TransactionDetailScreen({Key? key, required this.transaction, this.onEdit}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chi tiết giao dịch'),
        backgroundColor: theme.primaryColor,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: onEdit,
            tooltip: 'Chỉnh sửa',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Card(
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _detailRow('ID', transaction.id?.toString() ?? '-'),
                _detailRow('Số tiền', '${transaction.amount.toStringAsFixed(0)}đ'),
                _detailRow('Loại', transaction.type == 'income' ? 'Thu nhập' : transaction.type == 'expense' ? 'Chi tiêu' : transaction.type),
                _detailRow('Mô tả', transaction.description),
                _detailRow('Ngày', '${transaction.date.day}/${transaction.date.month}/${transaction.date.year}'),
                _detailRow('Danh mục', transaction.categoryId?.toString() ?? '-'),
                _detailRow('Khoản vay/Nợ', transaction.loanId?.toString() ?? '-'),
                _detailRow('Tạo lúc', transaction.createdAt.toString()),
                _detailRow('Cập nhật', transaction.updatedAt.toString()),
                const SizedBox(height: 24),
                Center(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.edit),
                    label: const Text('Chỉnh sửa'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    onPressed: onEdit,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          SizedBox(width: 120, child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold))),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

