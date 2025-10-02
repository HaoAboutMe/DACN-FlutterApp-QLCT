#📱 Mô tả dự án cũ
Đây là một ứng dụng quản lý chi tiêu cá nhân được phát triển bằng Flutter và sử dụng SQLite để lưu trữ dữ liệu. Ứng dụng tập trung vào việc giúp người dùng dễ dàng ghi lại, theo dõi và phân tích các khoản thu nhập, chi tiêu, vay/nợ trong đời sống hàng ngày, đồng thời hỗ trợ lập hạn mức chi tiêu (ngân sách) để kiểm soát chi tiêu tốt hơn.  

##🔑 Khởi đầu khi sử dụng app  
Khi mở app lần đầu, người dùng sẽ:  
- Nhập tên cá nhân để hiển thị lời chào (Ví dụ: “Xin chào Hảo”).  
- Nhập số dư hiện tại làm mốc ban đầu để quản lý chi tiêu.  
- (Tuỳ chọn) Đặt **hạn mức chi tiêu tổng cho tháng hiện tại** để bắt đầu theo dõi ngân sách.  

##💰 Quản lý giao dịch  
Người dùng có thể thêm các loại giao dịch khác nhau:  
- Thu nhập: Số tiền, mô tả, danh mục (lương, thưởng, phụ cấp, …), ngày tạo giao dịch.  
- Chi tiêu: Số tiền, mô tả, danh mục (ăn uống, đi chơi, mua sắm, …), ngày tạo giao dịch.  
- Cho vay: Thông tin gồm số tiền, mô tả, tên người mượn, số điện thoại (không bắt buộc), ngày mượn, ngày trả, trạng thái nhắc nhở hạn trả.  
  - Khoản vay cũ (trước khi dùng app): không trừ vào số dư.  
  - Khoản vay mới: tự động trừ số tiền cho vay khỏi số dư.  
- Nợ: Tương tự cho vay, gồm số tiền, mô tả, người cho vay, số điện thoại (không bắt buộc), ngày mượn, ngày trả.  
  - Nợ cũ (trước khi dùng app): không cộng vào số dư.  
  - Nợ mới: tự động cộng số tiền nợ vào số dư.  

##Danh mục  
- Mỗi giao dịch gắn với một danh mục (có tên + icon).  
- Người dùng có thể thêm danh mục mới ngay tại màn hình thêm giao dịch mà không cần thoát ra ngoài.  
- (Mới) **Danh mục có thể được gắn hạn mức chi tiêu riêng**, ví dụ: Ăn uống ≤ 2.000.000 VND/tháng, Giải trí ≤ 500.000 VND/tháng.  


##🏠 Màn chính (Dashboard)  
Hiển thị:  
- Lời chào kèm tên người dùng.  
- Số dư hiện tại.  
- Thông tin tóm tắt theo ngày/tuần/tháng/năm: tổng thu nhập, chi tiêu, cho vay, nợ.  
- Tiến độ chi tiêu so với hạn mức (ngân sách): progress bar hoặc cảnh báo nếu vượt hạn mức.  
- Giao dịch & Vay/Nợ gần nhất: hiển thị tối đa 5–10 mục, có nút “Xem tất cả”.  
- Nút thông báo (ở góc trên bên phải) hiển thị nhắc nhở hạn trả nợ hoặc đến hạn cho vay.  
- FloatingActionButton để thêm giao dịch nhanh.  
- BottomNavigationBar gồm 5 mục: Trang chủ, Giao dịch, Vay/Nợ, Thống kê, Cá nhân.  

##📂 Màn hình Giao dịch  
- Xem toàn bộ giao dịch.  
- Có 3 tab: Tất cả / Thu nhập / Chi tiêu.  
- Bộ lọc theo ngày/tháng/năm.  
- CRUD giao dịch.  
- Có thể chọn nhiều giao dịch để xóa cùng lúc.  

##🤝 Màn hình Vay/Nợ  
- Xem tất cả khoản vay/nợ.  
- Có 3 tab: Tất cả / Cho vay / Nợ.  
- Bộ lọc theo thời gian.  
- CRUD khoản vay/nợ.  
- Có thể chọn nhiều khoản để xóa cùng lúc.  
- Cho phép chỉnh sửa và đánh dấu đã trả.  

##📊 Màn hình Thống kê  
- Hiển thị số tiền thu nhập, chi tiêu, vay, nợ.  
- Biểu đồ trực quan: biểu đồ tròn và biểu đồ cột.  
- Có bộ lọc (ngày/tháng/năm) → thay đổi số liệu và biểu đồ tương ứng.  
- Theo dõi chi tiêu so với hạn mức: biểu đồ hoặc báo cáo phần trăm đã dùng.  
- Xuất báo cáo ra Excel hoặc PDF.  

##👤 Màn hình Cá nhân  
- Thông tin cá nhân: tên người dùng, số dư hiện tại.  
- Thiết lập hạn mức chi tiêu tổng cho tháng hoặc cho từng danh mục.  
- Cài đặt thông báo: bật/tắt nhắc nhở cuối ngày, nhắc hạn trả nợ.  
- CRUD danh mục (bao gồm chỉnh sửa hạn mức của danh mục).  
- Hướng dẫn sử dụng app.  
- Thông tin liên hệ & tác giả.  
- (Tuỳ chọn mở rộng): đổi giao diện dark mode/light mode.  
