import 'dart:developer';
import 'package:sqflite/sqflite.dart';
import '../database_helper.dart';
import '../../models/loan.dart';
import '../../models/transaction.dart' as transaction_model;
import '../../models/user.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LoanRepository {
  static final LoanRepository _instance = LoanRepository._internal();
  factory LoanRepository() => _instance;
  LoanRepository._internal();

  final DatabaseHelper _db = DatabaseHelper();

  Future<int> insertLoan(Loan loan) async {
    try {
      final db = await _db.database;
      final id = await db.insert('loans', loan.toMap());
      log('Thêm loan thành công với ID: $id');
      return id;
    } catch (e) {
      log('Lỗi thêm loan: $e');
      rethrow;
    }
  }

  Future<int> updateLoan(Loan loan) async {
    try {
      final db = await _db.database;

      final oldLoanMaps = await db.query(
        'loans',
        where: 'id = ?',
        whereArgs: [loan.id],
      );

      if (oldLoanMaps.isEmpty) {
        throw Exception('Loan không tồn tại');
      }

      final oldLoan = Loan.fromMap(oldLoanMaps.first);

      final count = await db.update(
        'loans',
        loan.toMap(),
        where: 'id = ?',
        whereArgs: [loan.id],
      );

      final currentUserId = await _getCurrentUserId();

      if (oldLoan.isOldDebt != loan.isOldDebt) {
        log('isOldDebt đã thay đổi: ${oldLoan.isOldDebt} -> ${loan.isOldDebt}');

        if (oldLoan.isOldDebt == 0 && loan.isOldDebt == 1) {
          log('Chuyển từ khoản vay mới sang cũ: Xóa transaction liên kết và hoàn trả số dư');

          final transactionMaps = await db.query(
            'transactions',
            where: 'loanId = ?',
            whereArgs: [loan.id],
            orderBy: 'createdAt ASC',
            limit: 1,
          );

          if (transactionMaps.isNotEmpty) {
            final transactionId = transactionMaps.first['id'] as int;
            final transactionType = transactionMaps.first['type'] as String;
            final transactionAmount = transactionMaps.first['amount'] as double;

            await db.delete(
              'transactions',
              where: 'id = ?',
              whereArgs: [transactionId],
            );

            log('Đã xóa transaction ID $transactionId (type: $transactionType)');

            double balanceChange = 0;
            if (transactionType == 'loan_received') {
              balanceChange = -transactionAmount;
              log('Hoàn trả số dư: Trừ $transactionAmount (đã nhận khi vay)');
            } else if (transactionType == 'loan_given') {
              balanceChange = transactionAmount;
              log('Hoàn trả số dư: Cộng $transactionAmount (đã cho vay)');
            }

            if (balanceChange != 0) {
              await db.rawUpdate(
                'UPDATE users SET balance = balance + ? WHERE id = ?',
                [balanceChange, currentUserId],
              );
              log('Đã hoàn trả số dư người dùng: ${balanceChange > 0 ? "+$balanceChange" : balanceChange}');
            }
          }
        } else if (oldLoan.isOldDebt == 1 && loan.isOldDebt == 0) {
          log('Chuyển từ khoản vay cũ sang mới: Tạo transaction mới');

          String transactionType;
          if (loan.loanType == 'borrow') {
            transactionType = 'loan_received';
          } else {
            transactionType = 'loan_given';
          }

          final newTransaction = transaction_model.Transaction(
            amount: loan.amount,
            description: loan.description ?? 'Khoản ${loan.loanType == 'borrow' ? 'vay' : 'cho vay'}: ${loan.personName}',
            date: loan.loanDate,
            categoryId: null,
            loanId: loan.id,
            type: transactionType,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );

          await db.insert('transactions', newTransaction.toMap());
          log('Đã tạo transaction mới với type: $transactionType');

          double balanceChange = 0;
          if (transactionType == 'loan_received') {
            balanceChange = loan.amount;
          } else if (transactionType == 'loan_given') {
            balanceChange = -loan.amount;
          }

          if (balanceChange != 0) {
            await db.rawUpdate(
              'UPDATE users SET balance = balance + ? WHERE id = ?',
              [balanceChange, currentUserId],
            );
            log('Cập nhật số dư người dùng: ${balanceChange > 0 ? "+$balanceChange" : balanceChange}');
          }
        }
      }

      if (loan.isOldDebt == 0 && (oldLoan.amount != loan.amount ||
          oldLoan.loanType != loan.loanType ||
          oldLoan.description != loan.description ||
          oldLoan.loanDate != loan.loanDate)) {
        final transactionMaps = await db.query(
          'transactions',
          where: 'loanId = ?',
          whereArgs: [loan.id],
          orderBy: 'createdAt ASC',
          limit: 1,
        );

        if (transactionMaps.isNotEmpty) {
          final transactionId = transactionMaps.first['id'] as int;
          final oldTransactionAmount = transactionMaps.first['amount'] as double;
          final oldTransactionType = transactionMaps.first['type'] as String;

          String newTransactionType;
          if (loan.loanType == 'borrow') {
            newTransactionType = 'loan_received';
          } else {
            newTransactionType = 'loan_given';
          }

          double balanceChange = 0;
          bool shouldUpdateBalance = (oldLoan.amount != loan.amount || oldLoan.loanType != loan.loanType);

          if (shouldUpdateBalance) {
            if (oldTransactionType == 'loan_received' || oldTransactionType == 'income') {
              balanceChange -= oldTransactionAmount;
            } else if (oldTransactionType == 'loan_given' || oldTransactionType == 'expense') {
              balanceChange += oldTransactionAmount;
            }

            if (newTransactionType == 'loan_received') {
              balanceChange += loan.amount;
            } else if (newTransactionType == 'loan_given') {
              balanceChange -= loan.amount;
            }
          }

          await db.update(
            'transactions',
            {
              'amount': loan.amount,
              'type': newTransactionType,
              'date': loan.loanDate.toIso8601String(),
              'description': loan.description ?? 'Khoản ${loan.loanType == 'borrow' ? 'vay' : 'cho vay'}: ${loan.personName}',
              'updatedAt': DateTime.now().toIso8601String(),
            },
            where: 'id = ?',
            whereArgs: [transactionId],
          );

          if (shouldUpdateBalance && balanceChange != 0) {
            await db.rawUpdate(
              'UPDATE users SET balance = balance + ? WHERE id = ?',
              [balanceChange, currentUserId],
            );
            log('Cập nhật số dư người dùng: ${balanceChange > 0 ? "+$balanceChange" : balanceChange}');
          }

          log('Cập nhật transaction liên quan với loan thành công');
        }
      }

      log('Cập nhật loan thành công');
      return count;
    } catch (e) {
      log('Lỗi cập nhật loan: $e');
      rethrow;
    }
  }

  Future<bool> _hasTransactionsForLoan(int loanId) async {
    try {
      final db = await _db.database;
      final result = await db.rawQuery(
        'SELECT COUNT(*) as count FROM transactions WHERE loanId = ?',
        [loanId],
      );
      final count = Sqflite.firstIntValue(result) ?? 0;
      log('Loan ID $loanId có $count giao dịch liên quan');
      return count > 0;
    } catch (e) {
      log('Lỗi kiểm tra transactions cho loan: $e');
      rethrow;
    }
  }

  Future<int> deleteLoan(int id) async {
    try {
      final db = await _db.database;

      final loanMaps = await db.query(
        'loans',
        where: 'id = ?',
        whereArgs: [id],
      );

      if (loanMaps.isEmpty) {
        log('Loan không tồn tại với ID: $id');
        return 0;
      }

      final loan = Loan.fromMap(loanMaps.first);
      log('Đang kiểm tra điều kiện xóa loan: ${loan.personName}, type: ${loan.loanType}, status: ${loan.status}');

      if (loan.status == 'paid' || loan.status == 'completed') {
        log('❌ Không thể xóa loan đã thanh toán: ${loan.personName}');
        throw Exception('LOAN_ALREADY_PAID');
      }

      final hasTransactions = await _hasTransactionsForLoan(id);
      if (hasTransactions) {
        log('❌ Không thể xóa loan vì đã có giao dịch liên quan: ${loan.personName}');
        throw Exception('LOAN_HAS_TRANSACTIONS');
      }

      if (loan.isOldDebt == 0) {
        log('Cập nhật số dư trước khi xóa loan mới...');
        await _updateUserBalanceAfterLoanDeletion(loan);
      }

      final count = await db.delete(
        'loans',
        where: 'id = ?',
        whereArgs: [id],
      );

      log('✅ Xóa loan thành công: ${loan.personName}, đã xóa $count bản ghi');
      return count;
    } catch (e) {
      log('❌ Lỗi xóa loan: $e');
      rethrow;
    }
  }

  Future<void> _updateUserBalanceAfterLoanDeletion(Loan loan) async {
    try {
      final db = await _db.database;
      final currentUserId = await _getCurrentUserId();

      final userMaps = await db.query(
        'users',
        where: 'id = ?',
        whereArgs: [currentUserId],
      );

      if (userMaps.isEmpty) {
        log('Không tìm thấy user hiện tại');
        return;
      }

      final currentUser = User.fromMap(userMaps.first);
      double balanceChange = 0;

      if (loan.loanType == 'lend') {
        balanceChange = loan.amount;
        log('Xóa khoản cho vay mới ${loan.amount} -> cộng lại vào số dư');
      } else if (loan.loanType == 'borrow') {
        balanceChange = -loan.amount;
        log('Xóa khoản đi vay mới ${loan.amount} -> trừ khỏi số dư');
      }

      final newBalance = currentUser.balance + balanceChange;

      await db.update(
        'users',
        {'balance': newBalance, 'updatedAt': DateTime.now().toIso8601String()},
        where: 'id = ?',
        whereArgs: [currentUserId],
      );

      log('Đã cập nhật số dư từ ${currentUser.balance} thành $newBalance (thay đổi: $balanceChange)');
    } catch (e) {
      log('Lỗi cập nhật số dư sau khi xóa loan: $e');
      rethrow;
    }
  }

  Future<List<Loan>> getAllLoans() async {
    try {
      final db = await _db.database;
      final maps = await db.query(
        'loans',
        orderBy: 'loanDate DESC, id DESC',
      );
      return List.generate(maps.length, (i) => Loan.fromMap(maps[i]));
    } catch (e) {
      log('Lỗi lấy danh sách loans: $e');
      rethrow;
    }
  }

  Future<Loan?> getLoanById(int id) async {
    try {
      final db = await _db.database;
      final maps = await db.query(
        'loans',
        where: 'id = ?',
        whereArgs: [id],
      );
      if (maps.isNotEmpty) {
        return Loan.fromMap(maps.first);
      }
      return null;
    } catch (e) {
      log('Lỗi lấy loan theo ID: $e');
      rethrow;
    }
  }

  Future<List<Loan>> getLoansByStatus(String status) async {
    try {
      final db = await _db.database;
      final maps = await db.query(
        'loans',
        where: 'status = ?',
        whereArgs: [status],
        orderBy: 'dueDate ASC, personName ASC',
      );
      return List.generate(maps.length, (i) => Loan.fromMap(maps[i]));
    } catch (e) {
      log('Lỗi lấy loans theo status: $e');
      rethrow;
    }
  }

  Future<int?> getLastInsertedLoanId() async {
    try {
      final db = await _db.database;
      final result = await db.rawQuery('SELECT last_insert_rowid() as id');
      if (result.isNotEmpty) {
        return result.first['id'] as int?;
      }
      return null;
    } catch (e) {
      log('Lỗi lấy last inserted loan ID: $e');
      rethrow;
    }
  }

  Future<List<Loan>> getLoansByType(String loanType) async {
    try {
      final db = await _db.database;
      final maps = await db.query(
        'loans',
        where: 'loanType = ?',
        whereArgs: [loanType],
        orderBy: 'loanDate DESC, id DESC',
      );
      return List.generate(maps.length, (i) => Loan.fromMap(maps[i]));
    } catch (e) {
      log('Lỗi lấy loans theo type: $e');
      rethrow;
    }
  }

  Future<List<Loan>> getUpcomingLoans(int days) async {
    try {
      final db = await _db.database;
      final upcomingDate = DateTime.now().add(Duration(days: days));

      final maps = await db.query(
        'loans',
        where: 'status = ? AND dueDate IS NOT NULL AND dueDate <= ?',
        whereArgs: ['active', upcomingDate.toIso8601String()],
        orderBy: 'dueDate ASC',
      );
      return List.generate(maps.length, (i) => Loan.fromMap(maps[i]));
    } catch (e) {
      log('Lỗi lấy loans sắp đến hạn: $e');
      rethrow;
    }
  }

  Future<List<Loan>> getOldDebts() async {
    try {
      final db = await _db.database;
      final maps = await db.query(
        'loans',
        where: 'isOldDebt = ?',
        whereArgs: [1],
        orderBy: 'loanDate DESC, id DESC',
      );
      return List.generate(maps.length, (i) => Loan.fromMap(maps[i]));
    } catch (e) {
      log('Lỗi lấy danh sách nợ cũ: $e');
      rethrow;
    }
  }

  Future<List<Loan>> getNewLoans() async {
    try {
      final db = await _db.database;
      final maps = await db.query(
        'loans',
        where: 'isOldDebt = ?',
        whereArgs: [0],
        orderBy: 'loanDate DESC, id DESC',
      );
      return List.generate(maps.length, (i) => Loan.fromMap(maps[i]));
    } catch (e) {
      log('Lỗi lấy danh sách khoản vay mới: $e');
      rethrow;
    }
  }

  Future<Map<String, int>> createLoanWithTransaction({
    required Loan loan,
    required transaction_model.Transaction transaction,
  }) async {
    final db = await _db.database;
    final currentUserId = await _getCurrentUserId();

    try {
      late int loanId;
      int? transactionId;

      await db.transaction((txn) async {
        loanId = await txn.insert('loans', loan.toMap());
        log('Tạo loan với ID: $loanId');

        if (loan.isOldDebt == 0) {
          log('Đây là khoản vay/nợ mới, tạo transaction và cập nhật số dư');

          final transactionWithLoanId = transaction.copyWith(loanId: loanId);
          transactionId = await txn.insert('transactions', transactionWithLoanId.toMap());
          log('Tạo transaction với ID: $transactionId');

          await _updateUserBalanceInTransaction(
            txn,
            currentUserId,
            loan.amount,
            transaction.type,
          );
        } else {
          log('Đây là khoản vay/nợ cũ, chỉ ghi nhận không tạo transaction ban đầu');
          transactionId = null;
        }
      });

      log('Tạo loan kèm transaction thành công cho user ID: $currentUserId');
      return {
        'loanId': loanId,
        'transactionId': transactionId ?? -1
      };
    } catch (e) {
      log('Lỗi tạo loan kèm transaction: $e');
      rethrow;
    }
  }

  Future<void> _updateUserBalanceInTransaction(
    Transaction txn,
    int userId,
    double amount,
    String transactionType,
  ) async {
    log('=== DEBUG _updateUserBalanceInTransaction ===');
    log('Input userId: $userId');
    log('Input amount: $amount');
    log('Input transactionType: $transactionType');

    final userMaps = await txn.query(
      'users',
      where: 'id = ?',
      whereArgs: [userId],
    );

    if (userMaps.isEmpty) {
      throw Exception('Không tìm thấy người dùng với ID: $userId');
    }

    final currentUser = User.fromMap(userMaps.first);
    double newBalance = currentUser.balance;

    log('Current user balance before update: ${currentUser.balance}');

    switch (transactionType) {
      case 'income':
      case 'debt_collected':
      case 'loan_received':
        newBalance += amount;
        log('Adding $amount to balance (type: $transactionType)');
        break;
      case 'expense':
      case 'loan_given':
      case 'debt_paid':
        newBalance -= amount;
        log('Subtracting $amount from balance (type: $transactionType)');
        break;
    }

    await txn.update(
      'users',
      {'balance': newBalance, 'updatedAt': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [userId],
    );

    log('Cập nhật số dư user ID $userId: ${currentUser.balance} -> $newBalance');
    log('=== END DEBUG _updateUserBalanceInTransaction ===');
  }

  Future<bool> markLoanAsPaid({
    required int loanId,
    required transaction_model.Transaction paymentTransaction,
    int? userId,
  }) async {
    final db = await _db.database;

    try {
      final currentUserId = userId ?? await _getCurrentUserId();
      log('Using user ID: $currentUserId for marking loan as paid');

      await db.transaction((txn) async {
        final loanMaps = await txn.query(
          'loans',
          where: 'id = ?',
          whereArgs: [loanId],
        );

        if (loanMaps.isEmpty) {
          throw Exception('Không tìm thấy khoản vay với ID: $loanId');
        }

        final currentLoan = Loan.fromMap(loanMaps.first);

        final updatedLoan = currentLoan.copyWith(
          status: 'paid',
          paidDate: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        await txn.update(
          'loans',
          updatedLoan.toMap(),
          where: 'id = ?',
          whereArgs: [loanId],
        );

        log('Cập nhật loan ID $loanId thành trạng thái paid (isOldDebt: ${currentLoan.isOldDebt})');

        final transactionWithLoanId = paymentTransaction.copyWith(loanId: loanId);
        await txn.insert('transactions', transactionWithLoanId.toMap());

        log('Tạo transaction thanh toán cho loan ID $loanId với type: ${paymentTransaction.type}');

        await _updateUserBalanceInTransaction(
          txn,
          currentUserId,
          paymentTransaction.amount,
          paymentTransaction.type,
        );
      });

      log('Đánh dấu loan đã thanh toán thành công');
      return true;
    } catch (e) {
      log('Lỗi đánh dấu loan đã thanh toán: $e');
      rethrow;
    }
  }

  Future<List<Loan>> getActiveLoansWithReminders() async {
    try {
      final db = await _db.database;
      final maps = await db.query(
        'loans',
        where: 'status IN (?, ?) AND reminderEnabled = ?',
        whereArgs: ['active', 'overdue', 1],
        orderBy: 'dueDate ASC',
      );
      return List.generate(maps.length, (i) => Loan.fromMap(maps[i]));
    } catch (e) {
      log('Lỗi lấy active loans với reminders: $e');
      rethrow;
    }
  }

  Future<int> updateLoanLastReminderSent(int loanId, DateTime sentAt) async {
    try {
      final db = await _db.database;
      final count = await db.update(
        'loans',
        {
          'lastReminderSent': sentAt.toIso8601String(),
          'updatedAt': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [loanId],
      );
      log('Cập nhật last reminder sent cho loan $loanId');
      return count;
    } catch (e) {
      log('Lỗi cập nhật last reminder sent: $e');
      rethrow;
    }
  }

  Future<int> updateLoanStatus(int loanId, String status) async {
    try {
      final db = await _db.database;
      final count = await db.update(
        'loans',
        {
          'status': status,
          'updatedAt': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [loanId],
      );
      log('Cập nhật trạng thái loan $loanId thành $status');
      return count;
    } catch (e) {
      log('Lỗi cập nhật trạng thái loan: $e');
      rethrow;
    }
  }

  Future<int> _getCurrentUserId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt('currentUserId') ?? 1;
      log('Current user ID: $userId');
      return userId;
    } catch (e) {
      log('Error getting current user ID: $e');
      return 1;
    }
  }
}

