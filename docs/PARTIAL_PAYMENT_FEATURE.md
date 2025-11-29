# Tính năng Trả nợ từng phần (Partial Payment)

## Tổng quan
Tính năng trả nợ từng phần cho phép người dùng thanh toán khoản vay theo từng đợt nhỏ thay vì phải trả toàn bộ số tiền một lần. Điều này giúp quản lý tài chính linh hoạt hơn và phản ánh chính xác tình trạng trả nợ thực tế.

## Các thay đổi chính

### 1. Model Loan (`lib/models/loan.dart`)
**Thêm field mới:**
- `amountPaid` (double): Tổng số tiền đã trả, mặc định = 0.0

**Thêm getters mới:**
- `remainingAmount`: Số tiền còn lại cần trả (amount - amountPaid)
- `paymentProgress`: Phần trăm đã trả (0-100)
- `hasPartialPayment`: Kiểm tra xem đã trả một phần chưa
- `isFullyPaid`: Kiểm tra xem đã trả đủ chưa

### 2. Database Schema (`lib/database/database_helper.dart`)
**Cập nhật version:** 4 → 5

**Thêm cột mới vào bảng `loans`:**
```sql
ALTER TABLE loans 
ADD COLUMN amountPaid REAL NOT NULL DEFAULT 0 CHECK (amountPaid >= 0)
```

**Migration tự động:** Khi người dùng cập nhật app, cột `amountPaid` sẽ được tự động thêm vào với giá trị mặc định là 0.

### 3. Loan Repository (`lib/database/repositories/loan_repository.dart`)
**Thêm method mới:**
```dart
Future<bool> makePartialPayment({
  required int loanId,
  required double paymentAmount,
  String? description,
  int? userId,
})
```

**Chức năng:**
- Kiểm tra điều kiện hợp lệ (số tiền > 0, không vượt quá số còn lại)
- Cập nhật `amountPaid` trong database
- Tự động chuyển status sang "paid" khi trả đủ
- Tạo transaction với type `debt_collected` (cho vay) hoặc `debt_paid` (đi vay)
- Cập nhật số dư người dùng:
  - **Cho vay (lend)**: Số dư tăng khi thu nợ
  - **Đi vay (borrow)**: Số dư giảm khi trả nợ
- Return `true` nếu đã trả đủ, `false` nếu còn nợ

### 4. UI - Partial Payment Screen (`lib/screens/loan/partial_payment_screen.dart`)
**Màn hình mới hoàn toàn với các tính năng:**

#### Hiển thị thông tin khoản vay
- Tên người cho/đi vay
- Tổng số tiền
- Đã trả
- Còn lại
- Progress bar (% hoàn thành)

#### Input thanh toán
- TextField nhập số tiền với format tự động (VND)
- Validate: Không được vượt quá số tiền còn lại
- Nút quick action:
  - **50%**: Trả một nửa số còn lại
  - **Toàn bộ**: Trả hết số còn lại

#### Ghi chú
- TextField tùy chọn để thêm mô tả cho lần thanh toán

#### Confirmation dialog
- Hiển thị số tiền sẽ thanh toán
- Thông báo ảnh hưởng đến số dư
- Hiển thị số tiền còn lại sau khi thanh toán

### 5. Loan Detail Screen (`lib/screens/loan/loan_detail_screen.dart`)
**Cập nhật UI:**

#### Section thông tin thanh toán (nếu có partial payment)
- Hiển thị số tiền đã trả (màu xanh)
- Hiển thị số tiền còn lại (màu cam)
- Progress bar với phần trăm hoàn thành
- Tự động ẩn khi chưa có thanh toán nào

#### Floating Action Buttons
Thay đổi từ 1 nút → 2 nút:

**Nút 1: Trả một phần** (Partial Payment)
- Icon: `Icons.payments`
- Màu: Theo loại khoản vay (cam cho lend, tím cho borrow)
- Navigate đến PartialPaymentScreen

**Nút 2: Đã thu/trả nợ** (Full Payment)
- Icon: `Icons.check_circle`
- Màu: Xanh lá (#4CAF50)
- Thanh toán toàn bộ số còn lại

**Ẩn cả 2 nút khi:** Khoản vay đã được đánh dấu là "paid" hoặc "completed"

## Luồng hoạt động

### Kịch bản 1: Trả nợ từng phần
1. User mở chi tiết khoản vay
2. Nhấn nút "Trả một phần"
3. Nhập số tiền muốn trả (ví dụ: 1,000,000 ₫)
4. Xác nhận
5. **Kết quả:**
   - `amountPaid` tăng thêm 1,000,000 ₫
   - Transaction mới được tạo
   - Số dư được cập nhật
   - Status vẫn là "active"
   - UI cập nhật realtime

### Kịch bản 2: Trả hết nợ qua partial payment
1. User mở chi tiết khoản vay (còn 500,000 ₫)
2. Nhấn nút "Trả một phần"
3. Nhấn nút "Toàn bộ" hoặc nhập 500,000 ₫
4. Xác nhận
5. **Kết quả:**
   - `amountPaid` = `amount` (đã trả đủ)
   - Status tự động chuyển sang "paid"
   - `paidDate` được set = ngày hiện tại
   - Transaction mới được tạo
   - Số dư được cập nhật
   - Notification (nếu có) bị hủy
   - FABs bị ẩn

### Kịch bản 3: Trả hết nợ qua full payment
1. User mở chi tiết khoản vay
2. Nhấn nút "Đã thu/trả nợ"
3. Xác nhận
4. **Kết quả:**
   - Status chuyển sang "paid"
   - `paidDate` được set
   - Transaction thanh toán toàn bộ số tiền còn lại được tạo
   - `amountPaid` không được cập nhật (giữ nguyên logic cũ cho tương thích)

## Tính toán số dư

### Cho vay (lend)
- **Tạo khoản vay mới:** Số dư **giảm** (tiền ra khỏi ví)
- **Thu nợ (partial/full):** Số dư **tăng** (tiền vào ví)

### Đi vay (borrow)
- **Tạo khoản vay mới:** Số dư **tăng** (nhận tiền)
- **Trả nợ (partial/full):** Số dư **giảm** (tiền ra khỏi ví)

## Transaction Types

### Khi tạo khoản vay mới
- `loan_given`: Cho vay (số dư giảm)
- `loan_received`: Đi vay (số dư tăng)

### Khi thanh toán
- `debt_collected`: Thu nợ từ người vay (số dư tăng)
- `debt_paid`: Trả nợ cho người cho vay (số dư giảm)

## Ví dụ cụ thể

### Ví dụ 1: Cho vay 10,000,000 ₫
```
Bước 1: Tạo khoản cho vay
- amount = 10,000,000
- amountPaid = 0
- remainingAmount = 10,000,000
- Số dư: -10,000,000 ₫

Bước 2: Thu nợ lần 1 (3,000,000 ₫)
- amountPaid = 3,000,000
- remainingAmount = 7,000,000
- paymentProgress = 30%
- Số dư: +3,000,000 ₫

Bước 3: Thu nợ lần 2 (7,000,000 ₫)
- amountPaid = 10,000,000
- remainingAmount = 0
- paymentProgress = 100%
- status = "paid"
- Số dư: +7,000,000 ₫

Tổng kết: Số dư quay về ban đầu
```

### Ví dụ 2: Đi vay 5,000,000 ₫
```
Bước 1: Tạo khoản đi vay
- amount = 5,000,000
- amountPaid = 0
- remainingAmount = 5,000,000
- Số dư: +5,000,000 ₫

Bước 2: Trả nợ lần 1 (2,000,000 ₫)
- amountPaid = 2,000,000
- remainingAmount = 3,000,000
- paymentProgress = 40%
- Số dư: -2,000,000 ₫

Bước 3: Trả nợ lần 2 (3,000,000 ₫)
- amountPaid = 5,000,000
- remainingAmount = 0
- paymentProgress = 100%
- status = "paid"
- Số dư: -3,000,000 ₫

Tổng kết: Số dư về lại như lúc chưa vay
```

## Tương thích ngược (Backward Compatibility)

### Dữ liệu cũ
- Tất cả khoản vay hiện có tự động có `amountPaid = 0`
- Không ảnh hưởng đến logic cũ
- Khoản vay đã "paid" trước đây vẫn giữ nguyên status

### Nâng cấp app
- Database tự động migrate sang version 5
- Không mất dữ liệu
- Tính năng mới chỉ áp dụng cho các khoản vay chưa thanh toán

## Testing

### Test cases cần kiểm tra:
1. ✅ Tạo khoản vay mới → amountPaid = 0
2. ✅ Trả một phần < số còn lại → cập nhật đúng
3. ✅ Trả đúng số còn lại → status = "paid"
4. ✅ Trả vượt quá số còn lại → show error
5. ✅ Trả số âm hoặc 0 → show error
6. ✅ Số dư cập nhật đúng sau mỗi lần trả
7. ✅ Progress bar hiển thị đúng phần trăm
8. ✅ Khoản vay đã "paid" → không cho phép thêm thanh toán
9. ✅ UI update realtime sau thanh toán
10. ✅ Transaction được tạo với type đúng

## Lợi ích

### Cho người dùng
- 🎯 Quản lý nợ linh hoạt hơn
- 📊 Theo dõi tiến độ trả nợ trực quan
- 💰 Trả dần theo khả năng tài chính
- ✅ Không bắt buộc trả một lần

### Cho ứng dụng
- 🔥 Tính năng mạnh mẽ, đáp ứng nhu cầu thực tế
- 📈 Dữ liệu chi tiết hơn về lịch sử thanh toán
- 🎨 UI/UX chuyên nghiệp
- 🔄 Tương thích ngược hoàn toàn

## Ghi chú kỹ thuật

- **Transaction safety:** Tất cả operations đều wrap trong database transaction để đảm bảo data integrity
- **Error handling:** Validate đầy đủ trước khi thực hiện thay đổi
- **Real-time updates:** Sử dụng `setState()` và navigation callbacks để update UI ngay lập tức
- **Logging:** Log chi tiết mọi bước để dễ debug
- **Type safety:** Sử dụng Dart type system đầy đủ, không có dynamic

---

**Tác giả:** GitHub Copilot  
**Ngày:** 29/11/2025  
**Version:** 1.0.0

