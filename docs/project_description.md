# Mô tả dự án - Ứng dụng Quản lý Chi tiêu Cá nhân

📱 **Tổng quan**
Đây là một ứng dụng quản lý chi tiêu cá nhân được phát triển bằng Flutter và sử dụng SQLite để lưu trữ dữ liệu. Ứng dụng tập trung vào việc giúp người dùng dễ dàng ghi lại, theo dõi và phân tích các khoản thu nhập, chi tiêu, vay/nợ trong đời sống hàng ngày.

## 🔑 Khởi đầu khi sử dụng app

Khi mở app lần đầu, người dùng sẽ:
1. Nhập tên cá nhân để hiển thị lời chào (Ví dụ: "Xin chào Hảo").
2. Nhập số dư hiện tại làm mốc ban đầu để quản lý chi tiêu.

## 💰 Quản lý giao dịch

Người dùng có thể thêm các loại giao dịch khác nhau:

### Thu nhập:
- Số tiền, mô tả, danh mục (lương, thưởng, phụ cấp, …).
- Ngày tạo giao dịch.

### Chi tiêu:
- Số tiền, mô tả, danh mục (ăn uống, đi chơi, mua sắm, …).
- Ngày tạo giao dịch.

### Cho vay:
- Thông tin gồm: số tiền, mô tả, tên người mượn, số điện thoại (không bắt buộc), ngày mượn, ngày trả, trạng thái nhắc nhở hạn trả.
- Phân loại:
  - **Khoản vay đã có trước khi dùng app**: không trừ vào số dư hiện tại.
  - **Khoản vay mới (sau khi dùng app)**: tự động trừ số tiền cho vay khỏi số dư.

### Nợ:
- Tương tự phần cho vay, gồm số tiền, mô tả, người cho vay, số điện thoại (không bắt buộc), ngày mượn, ngày trả.
- Phân loại:
  - **Nợ đã có trước khi dùng app**: không cộng vào số dư.
  - **Nợ mới (sau khi dùng app)**: tự động cộng số tiền nợ vào số dư.

### Danh mục:
- Mỗi giao dịch gắn với một danh mục (có tên + icon).
- Người dùng có thể thêm danh mục mới ngay tại màn hình thêm giao dịch mà không cần thoát ra ngoài.

## 🏠 Màn chính (Dashboard)

Hiển thị:
- Lời chào kèm tên người dùng.
- Số dư hiện tại.
- Thông tin tóm tắt theo ngày/tuần/tháng/năm: tổng thu nhập, chi tiêu, cho vay, nợ.

### Giao dịch & Vay/Nợ gần nhất:
- Hiển thị tối đa 5–10 giao dịch gần nhất (nút "Xem tất cả" để sang màn hình giao dịch).
- Hiển thị tối đa 5–10 khoản vay/nợ gần nhất (nút "Xem tất cả" để sang màn hình vay/nợ).

### Các thành phần UI:
- FloatingActionButton để thêm giao dịch nhanh.
- Nút thông báo (ở góc trên bên phải) hiển thị nhắc nhở hạn trả nợ hoặc đến hạn cho vay.
- BottomNavigationBar gồm 5 mục: Trang chủ, Giao dịch, Vay/Nợ, Thống kê, Cá nhân.

## 📂 Màn hình giao dịch

- Xem toàn bộ giao dịch.
- Có 3 tab: Tất cả / Thu nhập / Chi tiêu.
- Bộ lọc theo ngày/tháng/năm.
- CRUD giao dịch (Thêm, Sửa, Xóa, Hiển thị).
- Có thể chọn nhiều giao dịch để xóa cùng lúc.

## 🤝 Màn hình Vay/Nợ

- Xem tất cả khoản vay/nợ.
- Có 3 tab: Tất cả / Cho vay / Nợ.
- Bộ lọc theo thời gian.
- CRUD khoản vay/nợ.
- Có thể chọn nhiều khoản để xóa cùng lúc.
- Cho phép chỉnh sửa và đánh dấu đã trả.

## 📊 Màn hình Thống kê

- Hiển thị số tiền thu nhập, chi tiêu, vay, nợ.
- Biểu đồ trực quan: biểu đồ tròn và biểu đồ cột.
- Có bộ lọc (ngày/tháng/năm) → thay đổi số liệu và biểu đồ tương ứng.
- Xuất báo cáo ra Excel hoặc PDF.

## 👤 Màn hình Cá nhân

- Thông tin cá nhân: tên người dùng, số dư hiện tại.
- Cài đặt thông báo: bật/tắt nhắc nhở cuối ngày, nhắc hạn trà nợ.
- CRUD danh mục.
- Hướng dẫn sử dụng app.
- Thông tin liên hệ & tác giả.
- (Tuỳ chọn mở rộng): đổi giao diện dark mode/light mode.

