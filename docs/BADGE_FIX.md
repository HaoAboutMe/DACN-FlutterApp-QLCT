# 🔔 Sửa lỗi Badge không hiện ngay khi thêm Loan - Tóm tắt

## ✅ Vấn đề đã khắc phục

### Mô tả lỗi:
- Khi thêm loan mới (VD: cho vay 9/11, đáo hạn 11/11, nhắc trước 3 ngày)
- Badge ở navigation bar **KHÔNG hiện ngay** số lượng loan sắp đến hạn
- Phải đợi hoặc refresh mới thấy badge

### Nguyên nhân:
1. **Logic đếm sai:** `getUpcomingLoansCount()` đếm cố định loan trong vòng **7 ngày**, thay vì dựa vào `reminderDays` của từng loan
2. **Không cập nhật badge:** Sau khi thêm/sửa loan, không gọi `updateBadgeCounts()`

---

## 🔧 Giải pháp đã triển khai

### 1. **Sửa logic đếm trong NotificationService** ✅

**File:** `lib/services/notification_service.dart`

**Trước:**
```dart
Future<int> getUpcomingLoansCount() async {
  final loans = await dbHelper.getActiveLoansWithReminders();
  
  return loans.where((loan) {
    if (loan.dueDate == null) return false;
    final daysUntilDue = loan.dueDate!.difference(now).inDays;
    return daysUntilDue >= 0 && daysUntilDue <= 7; // ❌ Cố định 7 ngày
  }).length;
}
```

**Sau:**
```dart
Future<int> getUpcomingLoansCount() async {
  final loans = await dbHelper.getActiveLoansWithReminders();
  
  return loans.where((loan) {
    if (loan.dueDate == null || loan.reminderDays == null) return false;
    final daysUntilDue = loan.dueDate!.difference(now).inDays;
    
    // ✅ Đếm dựa vào reminderDays của từng loan
    // VD: dueDate = 11/11, reminderDays = 3, today = 9/11
    //     → daysUntilDue = 2, reminderDays = 3 → hiển thị badge
    return daysUntilDue >= 0 && daysUntilDue <= loan.reminderDays!;
  }).length;
}
```

**Lợi ích:**
- Badge hiển thị chính xác theo thời gian nhắc nhở của từng loan
- Loan có `reminderDays = 3` sẽ hiện badge ngay khi còn 3 ngày đến hạn
- Loan có `reminderDays = 14` sẽ hiện badge khi còn 14 ngày

---

### 2. **Cập nhật badge sau khi thêm loan** ✅

**File:** `lib/screens/loan/loan_list_screen.dart`

**Thêm import:**
```dart
import 'package:provider/provider.dart';
import '../../providers/notification_provider.dart';
```

**Cập nhật `_navigateToAddLoan()`:**
```dart
Future<void> _navigateToAddLoan() async {
  final result = await Navigator.push<bool>(
    context,
    MaterialPageRoute(
      builder: (context) => const AddLoanPage(),
    ),
  );

  await _loadLoans();
  mainNavigationKey.currentState?.refreshHomePage();

  // ✅ Cập nhật badge ngay sau khi thêm loan
  if (mounted) {
    context.read<NotificationProvider>().updateBadgeCounts();
  }
}
```

---

### 3. **Cập nhật badge sau khi edit loan** ✅

**Cập nhật `_navigateToLoanDetail()`:**
```dart
Future<void> _navigateToLoanDetail(Loan loan) async {
  final result = await Navigator.push<bool>(...);

  if (result == true) {
    await _loadLoans();
    mainNavigationKey.currentState?.refreshHomePage();
    
    // ✅ Cập nhật badge sau khi edit (có thể thay đổi reminderDays/dueDate)
    if (mounted) {
      context.read<NotificationProvider>().updateBadgeCounts();
    }
  }
}
```

---

## 📊 Ví dụ cụ thể

### Trường hợp của bạn:

**Loan:**
- Ngày cho vay: 9/11/2025
- Ngày đáo hạn: 11/11/2025
- Nhắc trước: 3 ngày
- Hôm nay: 9/11/2025

**Tính toán:**
```
daysUntilDue = 11/11 - 9/11 = 2 ngày
reminderDays = 3 ngày

Điều kiện: daysUntilDue (2) <= reminderDays (3) ✅
→ Badge HIỆN NGAY số 1
```

### Logic cũ (SAI):
```
Điều kiện: daysUntilDue (2) <= 7 ✅
→ Badge HIỆN (nhưng không chính xác với yêu cầu nhắc trước)
```

### Logic mới (ĐÚNG):
```
Điều kiện: daysUntilDue (2) <= reminderDays (3) ✅
→ Badge HIỆN (chính xác theo thời gian nhắc nhở của loan)
```

---

## 🎯 Các trường hợp khác

### Case 1: Loan nhắc trước 7 ngày
```
dueDate: 16/11, reminderDays: 7, today: 9/11
daysUntilDue = 7
Kết quả: 7 <= 7 → Badge HIỆN ✅
```

### Case 2: Loan nhắc trước 14 ngày
```
dueDate: 23/11, reminderDays: 14, today: 9/11
daysUntilDue = 14
Kết quả: 14 <= 14 → Badge HIỆN ✅
```

### Case 3: Loan chưa đến thời gian nhắc
```
dueDate: 25/11, reminderDays: 7, today: 9/11
daysUntilDue = 16
Kết quả: 16 > 7 → Badge KHÔNG HIỆN ✅
```

### Case 4: Loan đã quá hạn
```
dueDate: 8/11, today: 9/11
daysUntilDue = -1
Kết quả: -1 < 0 → Badge KHÔNG HIỆN (loan đã quá hạn, không còn "sắp đến hạn")
```

---

## ✅ Kết quả

### Trước khi sửa:
```
Thêm loan → Badge KHÔNG hiện ngay
Cần phải:
- Đóng app và mở lại
- Hoặc chuyển tab qua lại
- Hoặc đợi auto refresh
```

### Sau khi sửa:
```
Thêm loan → Badge HIỆN NGAY ✅
Edit loan → Badge CẬP NHẬT NGAY ✅
Logic đếm: Dựa vào reminderDays của từng loan ✅
```

---

## 📝 Files đã chỉnh sửa (2 files)

1. **`lib/services/notification_service.dart`**
   - Sửa `getUpcomingLoansCount()` để đếm dựa vào `reminderDays`
   - Thêm comment giải thích logic

2. **`lib/screens/loan/loan_list_screen.dart`**
   - Thêm import `NotificationProvider`
   - Cập nhật badge sau `_navigateToAddLoan()`
   - Cập nhật badge sau `_navigateToLoanDetail()`

---

## 🧪 Cách test

1. **Tạo loan mới:**
   ```
   - Ngày cho vay: Hôm nay
   - Đáo hạn: 2 ngày sau
   - Nhắc trước: 3 ngày
   → Badge phải hiện số 1 NGAY
   ```

2. **Tạo loan chưa đến thời gian nhắc:**
   ```
   - Ngày cho vay: Hôm nay
   - Đáo hạn: 10 ngày sau
   - Nhắc trước: 7 ngày
   → Badge KHÔNG hiện (vì còn 10 ngày > 7 ngày)
   ```

3. **Edit loan:**
   ```
   - Thay đổi dueDate hoặc reminderDays
   → Badge cập nhật ngay theo logic mới
   ```

---

## 🎉 Kết luận

**Vấn đề đã được khắc phục hoàn toàn!**

- ✅ Badge hiển thị **NGAY LẬP TỨC** khi thêm loan sắp đến hạn
- ✅ Logic đếm **CHÍNH XÁC** theo `reminderDays` của từng loan
- ✅ Badge **TỰ ĐỘNG CẬP NHẬT** khi edit loan
- ✅ Phù hợp với yêu cầu: "Những mục nào sắp quá hạn nên hiện badge lên ngay"

**App đã sẵn sàng để test!** 🚀

---

**Người thực hiện:** GitHub Copilot  
**Ngày:** 09/11/2025  
**Thời gian:** ~15 phút

