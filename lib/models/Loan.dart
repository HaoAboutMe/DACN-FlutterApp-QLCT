import 'package:flutter/foundation.dart';

@immutable
class Loan {
  /// ID của khoản vay/nợ (tự động tăng trong database)
  final int? id;

  /// Tên người vay/cho vay
  final String personName;

  /// Số điện thoại của người vay/cho vay (nullable)
  final String? personPhone;

  /// Số tiền vay/nợ (đơn vị: VND)
  final double amount;

  /// Loại khoản vay: "lend" (cho vay) hoặc "borrow" (đi vay)
  final String loanType;

  /// Ngày tạo khoản vay
  final DateTime loanDate;

  /// Ngày đáo hạn (nullable)
  final DateTime? dueDate;

  /// Trạng thái khoản vay: "active" (đang hoạt động), "paid" (đã thanh toán), "overdue" (quá hạn)
  final String status;

  /// Mô tả chi tiết về khoản vay (nullable)
  final String? description;

  /// Ngày thanh toán (nullable)
  final DateTime? paidDate;

  /// Bật/tắt tính năng nhắc nhở
  final bool reminderEnabled;

  /// Số ngày trước khi đáo hạn sẽ nhắc nhở (nullable)
  final int? reminderDays;

  /// Lần nhắc nhở cuối cùng (nullable)
  final DateTime? lastReminderSent;

  /// Thời gian tạo bản ghi
  final DateTime createdAt;

  /// Thời gian cập nhật cuối cùng
  final DateTime updatedAt;

  const Loan({
    this.id,
    required this.personName,
    this.personPhone,
    required this.amount,
    required this.loanType,
    required this.loanDate,
    this.dueDate,
    required this.status,
    this.description,
    this.paidDate,
    required this.reminderEnabled,
    this.reminderDays,
    this.lastReminderSent,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Tạo đối tượng Loan từ Map (sử dụng khi đọc từ database)
  factory Loan.fromMap(Map<String, dynamic> map) {
    return Loan(
      id: map['id'] as int?,
      personName: map['personName'] as String,
      personPhone: map['personPhone'] as String?,
      amount: (map['amount'] as num).toDouble(),
      loanType: map['loanType'] as String,
      loanDate: DateTime.parse(map['loanDate'] as String),
      dueDate: map['dueDate'] != null ? DateTime.parse(map['dueDate'] as String) : null,
      status: map['status'] as String,
      description: map['description'] as String?,
      paidDate: map['paidDate'] != null ? DateTime.parse(map['paidDate'] as String) : null,
      reminderEnabled: (map['reminderEnabled'] as int) == 1,
      reminderDays: map['reminderDays'] as int?,
      lastReminderSent: map['lastReminderSent'] != null ? DateTime.parse(map['lastReminderSent'] as String) : null,
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
    );
  }

  /// Chuyển đổi đối tượng Loan thành Map (sử dụng khi lưu vào database)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'personName': personName,
      'personPhone': personPhone,
      'amount': amount,
      'loanType': loanType,
      'loanDate': loanDate.toIso8601String(),
      'dueDate': dueDate?.toIso8601String(),
      'status': status,
      'description': description,
      'paidDate': paidDate?.toIso8601String(),
      'reminderEnabled': reminderEnabled ? 1 : 0,
      'reminderDays': reminderDays,
      'lastReminderSent': lastReminderSent?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  /// Tạo bản sao của Loan với các giá trị được cập nhật
  Loan copyWith({
    int? id,
    String? personName,
    String? personPhone,
    double? amount,
    String? loanType,
    DateTime? loanDate,
    DateTime? dueDate,
    String? status,
    String? description,
    DateTime? paidDate,
    bool? reminderEnabled,
    int? reminderDays,
    DateTime? lastReminderSent,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Loan(
      id: id ?? this.id,
      personName: personName ?? this.personName,
      personPhone: personPhone ?? this.personPhone,
      amount: amount ?? this.amount,
      loanType: loanType ?? this.loanType,
      loanDate: loanDate ?? this.loanDate,
      dueDate: dueDate ?? this.dueDate,
      status: status ?? this.status,
      description: description ?? this.description,
      paidDate: paidDate ?? this.paidDate,
      reminderEnabled: reminderEnabled ?? this.reminderEnabled,
      reminderDays: reminderDays ?? this.reminderDays,
      lastReminderSent: lastReminderSent ?? this.lastReminderSent,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Kiểm tra xem có phải là cho vay không
  bool get isLend => loanType == 'lend';

  /// Kiểm tra xem có phải là đi vay không
  bool get isBorrow => loanType == 'borrow';

  /// Kiểm tra xem khoản vay có đang hoạt động không
  bool get isActive => status == 'active';

  /// Kiểm tra xem khoản vay đã được thanh toán chưa
  bool get isPaid => status == 'paid';

  /// Kiểm tra xem khoản vay có bị quá hạn không
  bool get isOverdue => status == 'overdue';

  /// Kiểm tra xem khoản vay có quá hạn theo ngày không (tính toán thời gian thực)
  bool get isOverdueByDate {
    if (dueDate == null || isPaid) return false;
    return DateTime.now().isAfter(dueDate!);
  }

  /// Lấy tên hiển thị của loại khoản vay bằng tiếng Việt
  String get displayLoanType {
    switch (loanType) {
      case 'lend':
        return 'Cho vay';
      case 'borrow':
        return 'Đi vay';
      default:
        return 'Không xác định';
    }
  }

  /// Lấy tên hiển thị của trạng thái khoản vay bằng tiếng Việt
  String get displayStatus {
    switch (status) {
      case 'active':
        return 'Đang hoạt động';
      case 'paid':
        return 'Đã thanh toán';
      case 'overdue':
        return 'Quá hạn';
      default:
        return 'Không xác định';
    }
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Loan &&
        other.id == id &&
        other.personName == personName &&
        other.personPhone == personPhone &&
        other.amount == amount &&
        other.loanType == loanType &&
        other.loanDate == loanDate &&
        other.dueDate == dueDate &&
        other.status == status &&
        other.description == description &&
        other.paidDate == paidDate &&
        other.reminderEnabled == reminderEnabled &&
        other.reminderDays == reminderDays &&
        other.lastReminderSent == lastReminderSent &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        personName.hashCode ^
        personPhone.hashCode ^
        amount.hashCode ^
        loanType.hashCode ^
        loanDate.hashCode ^
        dueDate.hashCode ^
        status.hashCode ^
        description.hashCode ^
        paidDate.hashCode ^
        reminderEnabled.hashCode ^
        reminderDays.hashCode ^
        lastReminderSent.hashCode ^
        createdAt.hashCode ^
        updatedAt.hashCode;
  }

  @override
  String toString() {
    return 'Loan(id: $id, personName: $personName, personPhone: $personPhone, amount: $amount, loanType: $loanType, loanDate: $loanDate, dueDate: $dueDate, status: $status, description: $description, paidDate: $paidDate, reminderEnabled: $reminderEnabled, reminderDays: $reminderDays, lastReminderSent: $lastReminderSent, createdAt: $createdAt, updatedAt: $updatedAt)';
  }
}
