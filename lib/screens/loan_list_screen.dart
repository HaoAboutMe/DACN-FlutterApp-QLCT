// Task: Build a Flutter Loan Management screen
// Features: list of loans, filters, multi-select delete, badge, tổng kết, màu xanh chủ đạo
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'dart:convert';
import '../models/loan.dart';
import '../widgets/loan_item_card.dart';
import 'loan_detail_screen.dart';
import '../utils/currency_formatter.dart';
import '../database/database_helper.dart';

class LoanListScreen extends StatefulWidget {
  const LoanListScreen({Key? key}) : super(key: key);

  @override
  State<LoanListScreen> createState() => _LoanListScreenState();
}

class _LoanListScreenState extends State<LoanListScreen> {
  final DatabaseHelper _databaseHelper = DatabaseHelper();
  List<Loan> loans = [];
  List<Loan> filteredLoans = [];
  List<int> selectedIds = [];
  String filter = 'Tất cả';
  bool isSelectionMode = false;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadLoansFromDatabase();
  }

  Future<void> loadLoansFromDatabase() async {
    try {
      setState(() {
        isLoading = true;
      });

      // Load loans from database instead of mock data
      final dbLoans = await _databaseHelper.getAllLoans();

      setState(() {
        loans = dbLoans;
        applyFilter();
        isLoading = false;
      });
    } catch (e) {
      print('Error loading loans from database: $e');
      // Fallback to mock data if database fails
      await loadMockLoans();
    }
  }

  Future<void> loadMockLoans() async {
    try {
      final jsonStr = await rootBundle.loadString('mock/seed_loans.json');
      final List<dynamic> jsonList = json.decode(jsonStr);
      setState(() {
        loans = jsonList.map((e) => Loan.fromJson(e)).toList();
        applyFilter();
        isLoading = false;
      });
    } catch (e) {
      print('Error loading mock loans: $e');
      setState(() {
        loans = [];
        filteredLoans = [];
        isLoading = false;
      });
    }
  }

  void applyFilter() {
    final now = DateTime.now();
    setState(() {
      switch (filter) {
        case 'Tuần':
          final weekStart = now.subtract(Duration(days: now.weekday - 1));
          final weekEnd = weekStart.add(const Duration(days: 6));
          filteredLoans = loans.where((l) =>
            l.loanDate.isAfter(weekStart.subtract(const Duration(days: 1))) &&
            l.loanDate.isBefore(weekEnd.add(const Duration(days: 1)))
          ).toList();
          break;
        case 'Tháng':
          filteredLoans = loans.where((l) =>
            l.loanDate.month == now.month && l.loanDate.year == now.year
          ).toList();
          break;
        case 'Năm':
          filteredLoans = loans.where((l) => l.loanDate.year == now.year).toList();
          break;
        case 'Sắp hết hạn':
          filteredLoans = loans.where((l) =>
            l.dueDate != null &&
            l.dueDate!.isAfter(now) &&
            l.dueDate!.difference(now).inDays <= 7
          ).toList();
          break;
        default:
          filteredLoans = loans;
      }
    });
  }

  void onSelect(int id, bool selected) {
    setState(() {
      if (selected) {
        selectedIds.add(id);
        if (!isSelectionMode) isSelectionMode = true;
      } else {
        selectedIds.remove(id);
        if (selectedIds.isEmpty) isSelectionMode = false;
      }
    });
  }

  void onDeleteSelected() async {
    final count = selectedIds.length;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: Text('Bạn có chắc muốn xóa $count khoản vay/đi vay này không?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xác nhận', style: TextStyle(color: Colors.white))
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        // Delete from database
        for (int id in selectedIds) {
          await _databaseHelper.deleteLoan(id);
        }

        // Reload data from database
        await loadLoansFromDatabase();

        setState(() {
          selectedIds.clear();
          isSelectionMode = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Đã xóa $count khoản vay/đi vay thành công'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Lỗi khi xóa: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalLend = loans.where((l) => l.loanType == 'lend').fold<double>(0, (sum, l) => sum + l.amount);
    final totalBorrow = loans.where((l) => l.loanType == 'borrow').fold<double>(0, (sum, l) => sum + l.amount);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Khoản vay / đi vay'),
        backgroundColor: const Color(0xFF00A8CC), // Ocean blue - màu xanh nước biển của cá heo
        foregroundColor: Colors.white,
        actions: [
          if (selectedIds.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: onDeleteSelected,
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Tổng cho vay: ${CurrencyFormatter.formatVND(totalLend)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                Text('Tổng đi vay: ${CurrencyFormatter.formatVND(totalBorrow)}', style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          // Filter controls
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButton<String>(
                    value: filter,
                    onChanged: (value) {
                      setState(() {
                        filter = value!;
                        applyFilter();
                      });
                    },
                    items: <String>['Tất cả', 'Tuần', 'Tháng', 'Năm', 'Sắp hết hạn']
                        .map<DropdownMenuItem<String>>((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      isSelectionMode = !isSelectionMode;
                      if (!isSelectionMode) selectedIds.clear();
                    });
                  },
                  child: Text(isSelectionMode ? 'Hủy chọn' : 'Chọn nhiều'),
                ),
              ],
            ),
          ),
          Expanded(
            child: isLoading
                ? Center(child: CircularProgressIndicator())
                : ListView.builder(
              itemCount: filteredLoans.length,
              itemBuilder: (ctx, i) {
                final loan = filteredLoans[i];
                return LoanItemCard(
                  loan: loan,
                  isSelected: selectedIds.contains(loan.id),
                  onTap: () {
                    if (isSelectionMode) {
                      onSelect(loan.id!, !selectedIds.contains(loan.id));
                    } else {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => LoanDetailScreen(loanId: loan.id!),
                        ),
                      );
                    }
                  },
                  onLongPress: () {
                    onSelect(loan.id!, true);
                  },
                  onSelectChanged: (val) {
                    onSelect(loan.id!, val ?? false);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
