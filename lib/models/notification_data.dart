import 'package:flutter/foundation.dart';

@immutable
class NotificationData {
  /// ID của thông báo (tự động tăng trong database)
  final int? id;

  /// ID của khoản vay/nợ liên quan (nullable)
  final int? loanId;

  /// Loại thông báo (ví dụ: "reminder", "overdue", "payment")
  final String type;

  /// Tiêu đề của thông báo
  final String title;

  /// Nội dung chi tiết của thông báo
  final String body;

  /// Thời gian gửi thông báo
  final DateTime sentAt;

  /// Trạng thái đã đọc hay chưa
  final bool isRead;

  const NotificationData({
    this.id,
    this.loanId,
    required this.type,
    required this.title,
    required this.body,
    required this.sentAt,
    required this.isRead,
  });

  /// Tạo đối tượng NotificationData từ Map (sử dụng khi đọc từ database)
  factory NotificationData.fromMap(Map<String, dynamic> map) {
    return NotificationData(
      id: map['id'] as int?,
      loanId: map['loanId'] as int?,
      type: map['type'] as String,
      title: map['title'] as String,
      body: map['body'] as String,
      sentAt: DateTime.parse(map['sentAt'] as String),
      isRead: (map['isRead'] as int) == 1,
    );
  }

  /// Chuyển đổi đối tượng NotificationData thành Map (sử dụng khi lưu vào database)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'loanId': loanId,
      'type': type,
      'title': title,
      'body': body,
      'sentAt': sentAt.toIso8601String(),
      'isRead': isRead ? 1 : 0,
    };
  }

  /// Tạo bản sao của NotificationData với các giá trị được cập nhật
  NotificationData copyWith({
    int? id,
    int? loanId,
    String? type,
    String? title,
    String? body,
    DateTime? sentAt,
    bool? isRead,
  }) {
    return NotificationData(
      id: id ?? this.id,
      loanId: loanId ?? this.loanId,
      type: type ?? this.type,
      title: title ?? this.title,
      body: body ?? this.body,
      sentAt: sentAt ?? this.sentAt,
      isRead: isRead ?? this.isRead,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is NotificationData &&
        other.id == id &&
        other.loanId == loanId &&
        other.type == type &&
        other.title == title &&
        other.body == body &&
        other.sentAt == sentAt &&
        other.isRead == isRead;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        loanId.hashCode ^
        type.hashCode ^
        title.hashCode ^
        body.hashCode ^
        sentAt.hashCode ^
        isRead.hashCode;
  }

  @override
  String toString() {
    return 'NotificationData(id: $id, loanId: $loanId, type: $type, title: $title, body: $body, sentAt: $sentAt, isRead: $isRead)';
  }
}
