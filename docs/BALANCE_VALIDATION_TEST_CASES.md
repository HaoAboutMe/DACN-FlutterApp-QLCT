# Test Cases - Validation Số Dư

## Mục đích
Kiểm tra validation số dư cho giao dịch chi tiêu và khoản cho vay mới.

---

## Chuẩn bị Test

### Điều kiện ban đầu
- Số dư hiện tại: **1,000,000 VND**

---

## Test Cases - Giao Dịch Chi Tiêu (Expense)

### ✅ TC1: Thêm giao dịch chi tiêu - Số tiền hợp lệ
**Bước thực hiện:**
1. Mở màn hình "Thêm giao dịch"
2. Chọn loại: **Chi tiêu**
3. Nhập số tiền: **500,000 VND**
4. Chọn danh mục
5. Nhấn "Lưu"

**Kết quả mong đợi:**
- ✅ Giao dịch được lưu thành công
- ✅ Số dư mới: **500,000 VND**

---

### ❌ TC2: Thêm giao dịch chi tiêu - Số tiền vượt quá số dư
**Bước thực hiện:**
1. Mở màn hình "Thêm giao dịch"
2. Chọn loại: **Chi tiêu**
3. Nhập số tiền: **1,500,000 VND** (lớn hơn số dư)
4. Chọn danh mục
5. Nhấn "Lưu"

**Kết quả mong đợi:**
- ❌ Hiển thị lỗi: "Số tiền chi tiêu vượt quá số dư hiện tại (1,000,000 ₫)"
- ❌ Giao dịch KHÔNG được lưu
- ✅ Số dư không thay đổi: **1,000,000 VND**

---

### ❌ TC3: Thêm giao dịch chi tiêu - Số tiền bằng đúng số dư
**Bước thực hiện:**
1. Mở màn hình "Thêm giao dịch"
2. Chọn loại: **Chi tiêu**
3. Nhập số tiền: **1,000,000 VND** (bằng số dư)
4. Chọn danh mục
5. Nhấn "Lưu"

**Kết quả mong đợi:**
- ✅ Giao dịch được lưu thành công
- ✅ Số dư mới: **0 VND**

---

### ✅ TC4: Thêm giao dịch thu nhập - Không bị validate
**Bước thực hiện:**
1. Mở màn hình "Thêm giao dịch"
2. Chọn loại: **Thu nhập**
3. Nhập số tiền: **5,000,000 VND** (bất kỳ số tiền nào)
4. Chọn danh mục
5. Nhấn "Lưu"

**Kết quả mong đợi:**
- ✅ Giao dịch được lưu thành công (KHÔNG bị validate)
- ✅ Số dư mới: **6,000,000 VND** (1,000,000 + 5,000,000)

---

## Test Cases - Chỉnh Sửa Giao Dịch

### Điều kiện ban đầu cho test edit
- Số dư hiện tại: **1,000,000 VND**
- Có 1 giao dịch chi tiêu: **300,000 VND**

---

### ✅ TC5: Chỉnh sửa giao dịch chi tiêu - Tăng số tiền hợp lệ
**Bước thực hiện:**
1. Mở giao dịch chi tiêu **300,000 VND**
2. Chỉnh sửa số tiền thành: **500,000 VND**
3. Nhấn "Lưu"

**Kết quả mong đợi:**
- ✅ Giao dịch được cập nhật thành công
- ✅ Số dư khả dụng sau khi hoàn tác cũ: 1,000,000 + 300,000 = **1,300,000 VND**
- ✅ Số tiền mới (500,000) < Số dư khả dụng (1,300,000) → HỢP LỆ
- ✅ Số dư mới: 1,000,000 + 300,000 - 500,000 = **800,000 VND**

---

### ❌ TC6: Chỉnh sửa giao dịch chi tiêu - Tăng số tiền vượt quá
**Bước thực hiện:**
1. Mở giao dịch chi tiêu **300,000 VND**
2. Chỉnh sửa số tiền thành: **2,000,000 VND**
3. Nhấn "Lưu"

**Kết quả mong đợi:**
- ❌ Hiển thị lỗi: "Số tiền chi tiêu vượt quá số dư khả dụng (1,300,000 ₫)"
- ❌ Giao dịch KHÔNG được cập nhật
- ✅ Số dư không thay đổi: **1,000,000 VND**

---

### ❌ TC7: Chỉnh sửa giao dịch từ Thu nhập → Chi tiêu vượt quá số dư
**Bước thực hiện:**
1. Số dư hiện tại: **1,000,000 VND**
2. Có 1 giao dịch thu nhập: **800,000 VND**
3. Mở giao dịch thu nhập **800,000 VND**
4. Đổi loại thành: **Chi tiêu**
5. Giữ nguyên số tiền: **800,000 VND**
6. Nhấn "Lưu"

**Kết quả mong đợi:**
- ✅ Số dư khả dụng sau hoàn tác: 1,000,000 - 800,000 = **200,000 VND**
- ❌ Số tiền chi tiêu (800,000) > Số dư khả dụng (200,000) → KHÔNG HỢP LỆ
- ❌ Hiển thị lỗi: "Số tiền chi tiêu vượt quá số dư khả dụng (200,000 ₫)"
- ❌ Giao dịch KHÔNG được cập nhật

---

## Test Cases - Khoản Cho Vay Mới (New Lend)

### Điều kiện ban đầu
- Số dư hiện tại: **1,000,000 VND**

---

### ✅ TC8: Thêm khoản cho vay mới - Số tiền hợp lệ
**Bước thực hiện:**
1. Mở màn hình "Thêm khoản vay/nợ"
2. Chọn loại: **Cho vay**
3. Tắt toggle "Khoản vay/nợ cũ" (isOldDebt = false)
4. Nhập số tiền: **600,000 VND**
5. Điền thông tin người vay
6. Nhấn "Lưu"

**Kết quả mong đợi:**
- ✅ Khoản vay được lưu thành công
- ✅ Số dư mới: 1,000,000 - 600,000 = **400,000 VND**

---

### ❌ TC9: Thêm khoản cho vay mới - Số tiền vượt quá số dư
**Bước thực hiện:**
1. Mở màn hình "Thêm khoản vay/nợ"
2. Chọn loại: **Cho vay**
3. Tắt toggle "Khoản vay/nợ cũ" (isOldDebt = false)
4. Nhập số tiền: **1,500,000 VND** (lớn hơn số dư)
5. Điền thông tin người vay
6. Nhấn "Lưu"

**Kết quả mong đợi:**
- ❌ Hiển thị lỗi: "Số tiền cho vay vượt quá số dư hiện tại (1,000,000 ₫)"
- ❌ Khoản vay KHÔNG được lưu
- ✅ Số dư không thay đổi: **1,000,000 VND**

---

### ✅ TC10: Thêm khoản cho vay CŨ - Không bị validate
**Bước thực hiện:**
1. Mở màn hình "Thêm khoản vay/nợ"
2. Chọn loại: **Cho vay**
3. BẬT toggle "Khoản vay/nợ cũ" (isOldDebt = true)
4. Nhập số tiền: **5,000,000 VND** (bất kỳ số tiền nào)
5. Điền thông tin người vay
6. Nhấn "Lưu"

**Kết quả mong đợi:**
- ✅ Khoản vay được lưu thành công (KHÔNG bị validate)
- ✅ Số dư KHÔNG thay đổi: **1,000,000 VND** (khoản vay cũ không ảnh hưởng số dư)

---

### ✅ TC11: Thêm khoản đi vay mới - Không bị validate
**Bước thực hiện:**
1. Mở màn hình "Thêm khoản vay/nợ"
2. Chọn loại: **Đi vay**
3. Tắt toggle "Khoản vay/nợ cũ" (isOldDebt = false)
4. Nhập số tiền: **2,000,000 VND** (bất kỳ số tiền nào)
5. Điền thông tin người cho vay
6. Nhấn "Lưu"

**Kết quả mong đợi:**
- ✅ Khoản vay được lưu thành công (KHÔNG bị validate vì đi vay làm TĂNG số dư)
- ✅ Số dư mới: 1,000,000 + 2,000,000 = **3,000,000 VND**

---

## Test Cases - Chỉnh Sửa Khoản Cho Vay

### Điều kiện ban đầu
- Số dư hiện tại: **1,000,000 VND**
- Có 1 khoản cho vay mới: **400,000 VND** (isOldDebt = 0)

---

### ✅ TC12: Chỉnh sửa khoản cho vay mới - Tăng số tiền hợp lệ
**Bước thực hiện:**
1. Mở khoản cho vay mới **400,000 VND**
2. Chỉnh sửa số tiền thành: **800,000 VND**
3. Nhấn "Lưu"

**Kết quả mong đợi:**
- ✅ Số dư khả dụng sau hoàn tác: 1,000,000 + 400,000 = **1,400,000 VND**
- ✅ Số tiền mới (800,000) < Số dư khả dụng (1,400,000) → HỢP LỆ
- ✅ Khoản vay được cập nhật thành công
- ✅ Số dư mới: 1,000,000 + 400,000 - 800,000 = **600,000 VND**

---

### ❌ TC13: Chỉnh sửa khoản cho vay mới - Tăng số tiền vượt quá
**Bước thực hiện:**
1. Mở khoản cho vay mới **400,000 VND**
2. Chỉnh sửa số tiền thành: **2,000,000 VND**
3. Nhấn "Lưu"

**Kết quả mong đợi:**
- ✅ Số dư khả dụng sau hoàn tác: 1,000,000 + 400,000 = **1,400,000 VND**
- ❌ Số tiền mới (2,000,000) > Số dư khả dụng (1,400,000) → KHÔNG HỢP LỆ
- ❌ Hiển thị lỗi: "Số tiền cho vay vượt quá số dư khả dụng (1,400,000 ₫)"
- ❌ Khoản vay KHÔNG được cập nhật

---

### ✅ TC14: Chỉnh sửa khoản cho vay CŨ - Không bị validate
**Bước thực hiện:**
1. Có 1 khoản cho vay cũ: **5,000,000 VND** (isOldDebt = 1)
2. Mở khoản cho vay cũ
3. Chỉnh sửa số tiền thành: **10,000,000 VND**
4. Nhấn "Lưu"

**Kết quả mong đợi:**
- ✅ Khoản vay được cập nhật thành công (KHÔNG bị validate)
- ✅ Số dư KHÔNG thay đổi (khoản vay cũ không ảnh hưởng số dư)

---

## Tổng Kết Test Cases

| Test Case | Loại | Kết quả mong đợi | Validate? |
|-----------|------|------------------|-----------|
| TC1  | Thêm chi tiêu hợp lệ | ✅ Lưu thành công | Có |
| TC2  | Thêm chi tiêu vượt quá | ❌ Hiển thị lỗi | Có |
| TC3  | Thêm chi tiêu bằng số dư | ✅ Lưu thành công | Có |
| TC4  | Thêm thu nhập | ✅ Lưu thành công | Không |
| TC5  | Edit chi tiêu tăng hợp lệ | ✅ Lưu thành công | Có |
| TC6  | Edit chi tiêu tăng vượt quá | ❌ Hiển thị lỗi | Có |
| TC7  | Edit thu nhập → chi tiêu | ❌ Hiển thị lỗi | Có |
| TC8  | Thêm cho vay mới hợp lệ | ✅ Lưu thành công | Có |
| TC9  | Thêm cho vay mới vượt quá | ❌ Hiển thị lỗi | Có |
| TC10 | Thêm cho vay CŨ | ✅ Lưu thành công | Không |
| TC11 | Thêm đi vay mới | ✅ Lưu thành công | Không |
| TC12 | Edit cho vay mới tăng hợp lệ | ✅ Lưu thành công | Có |
| TC13 | Edit cho vay mới tăng vượt quá | ❌ Hiển thị lỗi | Có |
| TC14 | Edit cho vay CŨ | ✅ Lưu thành công | Không |

---

## Lưu ý khi Test

1. **Đa tiền tệ**: Kiểm tra với các đơn vị tiền tệ khác (USD, EUR, JPY)
   - App sẽ tự động convert về VND trước khi so sánh với số dư
   
2. **Edge cases**:
   - Số dư = 0
   - Số tiền nhập = 0
   - Số tiền âm (đã được validate ở level khác)

3. **UI/UX**:
   - SnackBar màu đỏ hiển thị rõ ràng
   - Loading state không bị "stuck"
   - Người dùng có thể sửa lại số tiền và thử lại

---

**Ngày tạo:** 29/11/2025
**Phiên bản:** 1.0

