# Changelog - Partial Payment Feature

## [Version 1.5.0] - 2025-11-29

### ✨ New Features

#### Partial Payment (Trả nợ từng phần)
- Thêm khả năng trả nợ theo từng đợt nhỏ thay vì phải trả toàn bộ một lần
- Hiển thị tiến độ thanh toán với progress bar và phần trăm
- Quick actions: Trả 50% hoặc toàn bộ số còn lại
- Tự động cập nhật số dư theo từng lần trả

### 🗄️ Database Changes

#### Schema Updates (v4 → v5)
- Thêm cột `amountPaid` vào bảng `loans`
- Migration tự động khi nâng cấp app
- Backward compatible với dữ liệu cũ

### 📱 UI/UX Improvements

#### Loan Detail Screen
- Hiển thị số tiền đã trả và còn lại
- Progress bar trực quan
- 2 floating action buttons: "Trả một phần" và "Đã thu/trả nợ"
- Realtime updates sau mỗi thanh toán

#### New Screen: Partial Payment
- Input số tiền với format VND tự động
- Validation chặt chẽ
- Confirmation dialog với preview
- Error handling chi tiết

### 🔧 Technical Updates

#### Models
- `Loan` model: Thêm field `amountPaid` và 4 getters mới
- Enhanced `copyWith()` method

#### Repositories
- `LoanRepository.makePartialPayment()`: Method mới xử lý partial payment
- Transaction-safe operations
- Auto status update khi trả đủ

#### Services
- Cập nhật logic tính toán số dư
- Hỗ trợ nhiều loại transaction: `debt_collected`, `debt_paid`

### 📚 Documentation
- `PARTIAL_PAYMENT_FEATURE.md`: Tài liệu chi tiết về tính năng
- Ví dụ cụ thể và use cases
- Testing checklist

### 🐛 Bug Fixes
- None (Feature mới)

### ⚠️ Breaking Changes
- None (Tương thích ngược hoàn toàn)

---

## Migration Guide

Không cần thao tác thủ công. Khi người dùng cập nhật app:
1. Database tự động migrate từ v4 lên v5
2. Tất cả khoản vay cũ có `amountPaid = 0`
3. Tính năng mới chỉ áp dụng cho khoản vay chưa thanh toán

## Testing Checklist

- [x] Model updates
- [x] Database migration
- [x] Repository methods
- [x] UI screens
- [x] Navigation flow
- [x] Balance calculation
- [x] Transaction creation
- [x] Error handling
- [x] No compile errors
- [x] Documentation

## Next Steps

1. Test trên thiết bị thật
2. Verify migration từ v4 lên v5
3. Test các edge cases
4. User acceptance testing

---

**Build**: Ready for testing  
**Status**: ✅ Complete

