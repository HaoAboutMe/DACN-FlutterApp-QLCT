# Mô tả dự án - Ứng dụng Quản lý Chi tiêu Cá nhân

📱 **Mô tả dự án: Ứng dụng quản lý chi tiêu cá nhân**

Đây là một ứng dụng di động quản lý chi tiêu cá nhân được phát triển bằng Flutter với SQLite để lưu trữ dữ liệu cục bộ và Firebase để xác thực người dùng. Ứng dụng hỗ trợ ghi chép, theo dõi và phân tích thu nhập, chi tiêu, khoản vay/nợ và lập ngân sách chi tiêu, giúp người dùng kiểm soát tài chính hiệu quả hơn.

---

## 🔐 Xác thực người dùng (mới)

- Ứng dụng tích hợp Firebase Authentication để:
  - Đăng ký tài khoản bằng Email & Mật khẩu
  - Đăng nhập bằng tài khoản đã có
  - Tự động đăng nhập sau lần đầu nếu chưa đăng xuất
- Giúp người dùng bảo mật dữ liệu và dễ dàng đồng bộ lên cloud trong tương lai.

---

## 🔑 Khởi đầu khi sử dụng app

Sau khi đăng nhập thành công, người dùng sẽ:
- Nhập tên cá nhân để hiển thị lời chào.
- Nhập số dư hiện tại làm mốc ban đầu.
- (Tuỳ chọn) Đặt hạn mức chi tiêu tổng cho tháng hiện tại.

---

## 💰 Quản lý giao dịch

Hỗ trợ các loại giao dịch:
- **Thu nhập**: số tiền, mô tả, danh mục, ngày tạo.
- **Chi tiêu**: số tiền, mô tả, danh mục, ngày tạo.
- **Cho vay**:
  - Tên người vay, số điện thoại (tuỳ chọn), ngày vay, hạn trả, có nhắc hạn trả.
  - *Khoản vay mới*: trừ số dư.
  - *Khoản vay cũ*: không ảnh hưởng số dư.
- **Nợ**: giống cho vay nhưng ở vai trò người nợ.
  - *Nợ mới*: cộng số dư.
  - *Nợ cũ*: không ảnh hưởng số dư.

---

## 🗂 Danh mục giao dịch

- Tạo, chỉnh sửa, xoá danh mục (tên + icon).
- Thêm danh mục ngay trong màn thêm giao dịch.
- (Mới) Mỗi danh mục có thể gắn hạn mức chi tiêu riêng.

---

## 🏠 Màn chính (Dashboard)

- Lời chào cá nhân.
- Số dư hiện tại.
- Tổng kết theo ngày / tuần / tháng / năm:
  - Thu nhập, chi tiêu, cho vay, nợ.
- Tiến độ ngân sách chi tiêu (tổng hoặc theo danh mục).
- Danh sách 5–10 giao dịch và khoản vay/nợ gần nhất.
- Nút thông báo nhắc hạn trả nợ.
- Nút thêm giao dịch nhanh (FloatingActionButton).
- Thanh điều hướng 5 tab:
  - **Trang chủ – Giao dịch – Vay/Nợ – Thống kê – Cá nhân**

---

## 📂 Màn hình Giao dịch

- Xem toàn bộ giao dịch.
- 3 tab: **Tất cả / Thu nhập / Chi tiêu**.
- Bộ lọc theo ngày, tháng, năm.
- CRUD giao dịch.
- Xoá nhiều giao dịch cùng lúc.

---

## 🤝 Màn hình Vay/Nợ

- 3 tab: **Tất cả / Cho vay / Nợ**
- Bộ lọc thời gian.
- CRUD khoản vay/nợ.
- Xoá nhiều khoản cùng lúc.
- Đánh dấu đã trả.

---

## 📊 Màn hình Thống kê

- Hiển thị số liệu **thu/chi/vay/nợ**.
- Biểu đồ tròn và biểu đồ cột.
- Bộ lọc theo ngày, tháng, năm.
- So sánh chi tiêu với hạn mức ngân sách.
- Xuất báo cáo ra **Excel hoặc PDF**.

---

## 👤 Màn hình Cá nhân (đã cập nhật)

- Thông tin cá nhân: tên hiển thị, số dư hiện tại.
- **Quản lý tài khoản**:
  - Hiển thị email đăng nhập.
  - Đổi mật khẩu.
  - Đăng xuất tài khoản.
- Thiết lập hạn mức chi tiêu tổng hoặc theo danh mục.
- Cài đặt thông báo: bật/tắt nhắc giao dịch, nhắc hạn trả nợ.
- CRUD danh mục.
- Hướng dẫn sử dụng.
- Thông tin tác giả.
- (Tuỳ chọn): Dark mode / Light mode.
