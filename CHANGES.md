Mục tiêu:
Hoàn thiện và tái thiết kế phần bộ lọc (Filter) của LoanListScreen trong ứng dụng quản lý chi tiêu cá nhân Whales Spent, đảm bảo giao diện gọn gàng, rõ ràng và thân thiện với người dùng phổ thông.

Yêu cầu tổng thể:
Ứng dụng cần có hai nhóm bộ lọc riêng biệt, hoạt động độc lập và không gây xung đột logic.
Cụ thể:
1.	Bộ lọc khoản vay (theo trạng thái và hạn)
2.	Bộ lọc thời gian (theo thời điểm tạo khoản vay)
      Hai nhóm này được thể hiện bằng hai nút riêng biệt ở đầu màn hình:
      [ Bộ lọc khoản vay ⌄ ]   [ Thời gian ⌄ ]
      Khi người dùng bấm vào từng nút, ứng dụng mở ra BottomSheet riêng biệt cho từng loại bộ lọc.

1️. Bộ lọc khoản vay (Loan Filter Sheet)
•	Khi người dùng bấm “Bộ lọc khoản vay ⌄”, hiển thị một BottomSheet có các nhóm chọn dạng checkbox:
•	Trạng thái:
•	☑ Đang hoạt động  
•	☐ Đã thanh toán
•
•	Tình trạng hạn:
•	☑ Sắp đến hạn (≤7 ngày)  
•	☐ Đã quá hạn  
•	☐ Không có hạn
•
•	[Đặt lại]                     [Áp dụng]
•	Người dùng có thể chọn nhiều mục cùng lúc (ví dụ: “Đang hoạt động” + “Sắp đến hạn”).
•	Nếu không chọn gì, mặc định hiển thị tất cả khoản vay.
•	Khi nhấn “Áp dụng”, danh sách được cập nhật theo các điều kiện vừa chọn.
•	Khi nhấn “Đặt lại”, bỏ toàn bộ lựa chọn và hiển thị lại tất cả khoản vay.
Hành vi dữ liệu mong muốn:
•	“Sắp đến hạn” = các khoản chưa thanh toán, có due_date trong vòng 7 ngày tới tính từ ngày hiện tại.
•	“Đã quá hạn” = các khoản chưa thanh toán, có due_date nhỏ hơn ngày hiện tại.
•	“Không có hạn” = các khoản vay không có due_date.

2️. Bộ lọc thời gian (Loan Time Filter Sheet)
•	Khi người dùng bấm “Thời gian ⌄”, hiển thị BottomSheet khác với nội dung:
•	Lọc theo thời gian tạo
•
•	(•) Tất cả thời gian  
•	( ) Chọn tháng/năm cụ thể
•
•	📅 Tháng được chọn: [ Tháng 11, 2025 ⌄ ]
•
•	[Đặt lại]                     [Áp dụng]
•	Mặc định chọn “Tất cả thời gian”.
•	Nếu chọn “Chọn tháng/năm cụ thể”, cho phép người dùng chọn tháng bằng MonthPicker.
•	Khi nhấn “Áp dụng”, chỉ hiển thị các khoản vay có loan_date thuộc tháng/năm được chọn.
•	Khi nhấn “Đặt lại”, quay về “Tất cả thời gian”.

3. Hiển thị kết quả sau khi lọc:
   •	Sau khi người dùng áp dụng một hoặc nhiều bộ lọc, hiển thị các chip nhỏ phía trên danh sách để tóm tắt bộ lọc hiện tại.
   Ví dụ:
   [Đang hoạt động ✕] [Sắp đến hạn ✕] [Tháng 11, 2025 ✕]
   •	Mỗi chip có biểu tượng “✕” để gỡ nhanh từng bộ lọc riêng lẻ.
   •	Nếu không còn bộ lọc nào, ẩn toàn bộ dãy chip này.

4️. Trải nghiệm người dùng mong muốn:
•	Hai nhóm lọc hoạt động độc lập, không gây xung đột dữ liệu.
•	Người dùng có thể lọc khoản vay theo trạng thái/hạn mà không cần chọn thời gian.
•	Giao diện phải rõ ràng, cân đối, dễ hiểu, tương thích cả Light Mode và Dark Mode.
•	Các thao tác lọc, áp dụng, đặt lại và hiển thị chip phải mượt mà, nhất quán và tự nhiên.
•	Sau khi áp dụng filter, danh sách cập nhật ngay mà không cần tải lại toàn bộ màn hình.

5️. Bố cục tổng thể màn hình (minh họa dạng text UI):
╔════════════════════════════════════════╗
║ [ Bộ lọc khoản vay ⌄ ]  [ Thời gian ⌄ ] ║
╚════════════════════════════════════════╝

[Đang hoạt động ✕] [Sắp đến hạn ✕] [Tháng 11, 2025 ✕]

💰 Nguyễn Văn A — 5.000.000đ
🗓  Hạn: 10/11/2025 — Còn 7 ngày

💰 Trần Minh B — 3.000.000đ
🗓  Hạn: Không có hạn — Đang hoạt động

Kết quả mong muốn:
Sau khi hoàn thiện, LoanListScreen phải có:
•	Hai nút filter rõ ràng, hoạt động độc lập.
•	Hai sheet lọc riêng biệt: trạng thái/hạn vay và thời gian tạo.
•	Chip hiển thị tóm tắt filter đang dùng.
•	Logic hiển thị “Sắp đến hạn”, “Quá hạn”, “Không có hạn” chuẩn xác và dễ hiểu.
•	Giao diện thống nhất với phong cách hiện tại của ứng dụng Whales Spent (màu sắc, typography, padding, radius).

Yêu cầu cuối cùng:
Refactor toàn bộ phần filter trong LoanListScreen theo đúng mô tả trên,
đảm bảo UX thống nhất, dễ dùng và thân thiện, không cần thêm chức năng khác ngoài phạm vi bộ lọc.

