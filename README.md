# 📱 Ứng Dụng Quản Lý Chi Tiêu

> Ứng dụng di động được phát triển bằng Flutter để quản lý chi tiêu cá nhân

[![Flutter](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-0175C2?style=for-the-badge&logo=dart&logoColor=white)](https://dart.dev)
[![SQLite](https://img.shields.io/badge/SQLite-07405E?style=for-the-badge&logo=sqlite&logoColor=white)](https://sqlite.org)

## 📋 Mục Lục

- [Giới Thiệu](#-giới-thiệu)
- [Tính Năng](#-tính-năng)
- [Cài Đặt](#-cài-đặt)
- [Cấu Trúc Thư Mục](#-cấu-trúc-thư-mục)
- [Sử Dụng](#-sử-dụng)
- [Công Nghệ Sử Dụng](#-công-nghệ-sử-dụng)
- [Tác Giả](#-tác-giả)

## 🎯 Giới Thiệu

Ứng dụng Quản Lý Chi Tiêu là một công cụ di động giúp người dùng theo dõi và quản lý các khoản thu chi cá nhân một cách hiệu quả. Ứng dụng được phát triển bằng Flutter với cơ sở dữ liệu SQLite, cung cấp giao diện thân thiện và dễ sử dụng.

## ✨ Tính Năng

- 💰 **Quản lý giao dịch**: Thêm, sửa, xóa các khoản thu/chi
- 📊 **Phân loại chi tiêu**: Tổ chức giao dịch theo danh mục
- 💳 **Quản lý khoản vay**: Theo dõi các khoản vay/cho vay
- 🔔 **Thông báo**: Nhắc nhở các giao dịch quan trọng
- 📈 **Báo cáo**: Xem báo cáo chi tiết về tình hình tài chính
- 🎨 **Giao diện thân thiện**: Thiết kế đẹp mắt và dễ sử dụng

## 🚀 Cài Đặt

### Yêu Cầu Hệ Thống

- Flutter SDK (phiên bản 3.0+)
- Dart SDK
- Android Studio / VS Code
- Thiết bị Android/iOS hoặc Emulator

### Các Bước Cài Đặt

1. **Clone dự án về máy:**
   ```bash
   git clone https://github.com/<tên-tài-khoản>/<tên-repo>.git
   cd app_qlct
   ```

2. **Cài đặt dependencies:**
   ```bash
   flutter pub get
   ```

3. **Chạy ứng dụng trên thiết bị/emulator:**
   ```bash
   flutter run
   ```

4. **Build APK (tùy chọn):**
   ```bash
   flutter build apk --release
   ```

## 📂 Cấu Trúc Thư Mục

```
lib/
├── 📁 models/         # Khai báo các model
│   ├── category.dart     # Model danh mục
│   ├── transaction.dart  # Model giao dịch
│   ├── loan.dart        # Model khoản vay
│   └── notification.dart # Model thông báo
├── 📁 database/       # DatabaseHelper và các truy vấn SQLite
│   └── database_helper.dart
├── 📁 screens/        # Các màn hình giao diện
│   ├── home_screen.dart
│   ├── transaction_screen.dart
│   └── settings_screen.dart
├── 📁 widgets/        # Các widget dùng chung
│   ├── custom_button.dart
│   └── transaction_card.dart
└── 📄 main.dart       # File chạy chính
```

## 📖 Sử Dụng

1. **Khởi động ứng dụng** và tạo tài khoản hoặc đăng nhập
2. **Thêm danh mục** cho các loại chi tiêu
3. **Ghi lại giao dịch** hàng ngày
4. **Xem báo cáo** để theo dõi tình hình tài chính
5. **Thiết lập thông báo** để nhắc nhở các khoản chi quan trọng

## 🛠 Công Nghệ Sử Dụng

| Công nghệ | Mô tả |
|-----------|-------|
| **Flutter** | Framework phát triển ứng dụng đa nền tảng |
| **Dart** | Ngôn ngữ lập trình chính |
| **SQLite** | Cơ sở dữ liệu cục bộ |
| **Material Design** | Thiết kế giao diện người dùng |

## 📱 Screenshots

*[Thêm screenshots của ứng dụng tại đây]*

## 🤝 Đóng Góp

Chúng tôi hoan nghênh mọi đóng góp! Nếu bạn muốn đóng góp:

1. Fork dự án
2. Tạo branch tính năng (`git checkout -b feature/AmazingFeature`)
3. Commit thay đổi (`git commit -m 'Add some AmazingFeature'`)
4. Push lên branch (`git push origin feature/AmazingFeature`)
5. Tạo Pull Request

## 📄 License

Dự án này được phân phối dưới giấy phép MIT. Xem file `LICENSE` để biết thêm chi tiết.

## 👨‍💻 Tác Giả

**Nguyễn Lê Hoàn Hảo**
- 🎓 Sinh viên năm 4 HUTECH
- 📚 Đề tài đồ án chuyên ngành Công nghệ Phần mềm
- 📧 Email: [your-email@example.com]
- 💼 LinkedIn: [Your LinkedIn Profile]

---

<div align="center">
  <p>⭐ Nếu dự án hữu ích, hãy cho một star nhé! ⭐</p>
  <p>Được tạo với ❤️ bởi Nguyễn Lê Hoàn Hảo</p>
</div>
