# CHANGES LOG

## 2025-01-09: Loan Feature Implementation

### New Files Added:
- `mock/seed_loans.json` - Mock data for testing loan feature (6 sample loans)
- `lib/screens/loan_list_screen.dart` - Main loan list screen with filters and multi-select
- `lib/screens/loan_detail_screen.dart` - Loan detail screen with edit dialog placeholder
- `lib/widgets/loan_item_card.dart` - Reusable loan item card widget

### Modified Files:
- `pubspec.yaml` - Added mock/ folder to assets for loading seed data
- `lib/models/loan.dart` - Already had proper fromJson method and currency formatting

### Features Implemented:
✅ Loan List Screen:
- Displays all loans (lend/borrow) with proper Vietnamese currency formatting
- Filter controls: Tất cả, Tuần, Tháng, Năm, Sắp hết hạn
- Shows total lend and borrow amounts at top
- Badge system: "MỚI" for new loans, "CŨ" for old loans
- Multi-select mode with long-press activation
- Confirmation dialog for bulk delete operations
- Green color theme matching home_page.dart

✅ Loan Item Card:
- Shows person name, amount, loan type (lend/borrow) with color coding
- Displays start date, due date, and status (còn hạn/sắp hết hạn/quá hạn)
- Visual badges for new/old loan indicators
- Checkbox selection for multi-select mode
- Proper tap and long-press handling

✅ Loan Detail Screen:
- Complete loan information display in card layout
- Edit button that shows "🛠️ Tính năng chỉnh sửa đang được phát triển" dialog
- Proper currency formatting and date display
- Green theme consistent with app design

### Fixed Issues:
- Corrected import paths for currency formatter and models
- Added mock data file to pubspec.yaml assets
- Fixed currency formatting to use CurrencyFormatter.formatVND() method
- Resolved missing updatedAt parameter in Loan constructor calls

### Testing:
- Mock data includes 6 sample loans with various types, statuses, and dates
- All filter options work with the sample data
- Multi-select and delete confirmation tested
- Navigation between list and detail screens functional
