# 🔧 Hướng Dẫn Khắc Phục Dark Mode - Whales Spent

## 📋 Checklist Các Lỗi Đã Được Sửa

### ✅ 1. Cấu Hình Theme Cơ Sở (HOÀN THÀNH)

**File đã cập nhật:**
- `lib/config/app_theme.dart` - Thêm surfaceVariant, outline, shadow cho phân tầng rõ ràng
- `lib/providers/theme_provider.dart` - Quản lý theme toàn cục
- `lib/utils/theme_helper.dart` - Helper utilities cho dễ sử dụng

**Cải thiện:**
- ✅ Light Theme có shadow rõ ràng: `Color(0x1A000000)` 
- ✅ Dark Theme có shadow đậm hơn: `Color(0x40000000)`
- ✅ surfaceVariant cho phân tầng card/container
- ✅ outline cho border/divider
- ✅ Elevation cho Card: Light (2), Dark (4)

### 🔧 2. Cách Khắc Phục Từng Loại Widget

#### A. Scaffold & Background
```dart
// ❌ SAI
Scaffold(
  backgroundColor: Colors.white,
)

// ✅ ĐÚNG
Scaffold(
  backgroundColor: Theme.of(context).scaffoldBackgroundColor,
)
```

#### B. AppBar
```dart
// ❌ SAI
AppBar(
  backgroundColor: HomeColors.primary,
  foregroundColor: Colors.white,
)

// ✅ ĐÚNG
AppBar(
  backgroundColor: Theme.of(context).colorScheme.primary,
  foregroundColor: Theme.of(context).colorScheme.onPrimary,
)
```

#### C. Card với Shadow/Elevation
```dart
// ❌ SAI
Container(
  decoration: BoxDecoration(
    color: Colors.white,
    boxShadow: [
      BoxShadow(color: Colors.black.withOpacity(0.1)),
    ],
  ),
)

// ✅ ĐÚNG - Sử dụng ThemedCard helper
import '../../../utils/theme_helper.dart';

ThemedCard(
  child: YourContent(),
  // elevation tự động: Light (2-4), Dark (4-8)
)

// ✅ ĐÚNG - Hoặc tự làm
Container(
  decoration: BoxDecoration(
    color: Theme.of(context).colorScheme.surface,
    borderRadius: BorderRadius.circular(16),
    boxShadow: [
      BoxShadow(
        color: context.isDark
          ? Colors.black.withValues(alpha: 0.3)
          : Colors.black.withValues(alpha: 0.08),
        blurRadius: context.isDark ? 8 : 10,
        offset: Offset(0, context.isDark ? 3 : 4),
      ),
    ],
  ),
)
```

#### D. Text với Tương Phản
```dart
// ❌ SAI
Text(
  'Hello',
  style: TextStyle(color: Colors.black),
)

// ✅ ĐÚNG
Text(
  'Hello',
  style: TextStyle(
    color: Theme.of(context).colorScheme.onSurface,
  ),
)

// Hoặc dùng textTheme
Text(
  'Hello',
  style: Theme.of(context).textTheme.bodyLarge,
)

// Text phụ (secondary)
Text(
  'Subtitle',
  style: TextStyle(
    color: Theme.of(context).colorScheme.onSurfaceVariant,
  ),
)
```

#### E. Icon
```dart
// ❌ SAI
Icon(Icons.home, color: Colors.black)

// ✅ ĐÚNG
Icon(
  Icons.home,
  color: Theme.of(context).iconTheme.color,
)

// Hoặc
Icon(
  Icons.home,
  color: Theme.of(context).colorScheme.onSurface,
)
```

#### F. Divider
```dart
// ❌ SAI
Divider(color: Colors.grey[200])

// ✅ ĐÚNG
Divider(color: Theme.of(context).dividerColor)

// Hoặc
Divider(color: Theme.of(context).colorScheme.outline)
```

#### G. Bottom Navigation Bar
```dart
// ❌ SAI
BottomNavigationBar(
  backgroundColor: Colors.white,
  selectedItemColor: Colors.blue,
  unselectedItemColor: Colors.grey,
)

// ✅ ĐÚNG - Theme tự động
// Không cần set màu, đã có trong theme
BottomNavigationBar(
  items: [...],
)
```

#### H. Dialog
```dart
// ❌ SAI
Dialog(
  backgroundColor: Colors.white,
  child: Container(color: Colors.white),
)

// ✅ ĐÚNG
Dialog(
  backgroundColor: Theme.of(context).colorScheme.surface,
  child: Container(
    color: Theme.of(context).colorScheme.surface,
  ),
)
```

#### I. ListTile
```dart
// ❌ SAI
ListTile(
  tileColor: Colors.white,
  title: Text('Item', style: TextStyle(color: Colors.black)),
  subtitle: Text('Subtitle', style: TextStyle(color: Colors.grey)),
)

// ✅ ĐÚNG
ListTile(
  tileColor: Theme.of(context).colorScheme.surface,
  title: Text('Item'), // Tự động dùng onSurface
  subtitle: Text('Subtitle'), // Tự động dùng onSurfaceVariant
)
```

#### J. TextField / TextFormField
```dart
// ❌ SAI
TextField(
  decoration: InputDecoration(
    fillColor: Colors.white,
    filled: true,
  ),
)

// ✅ ĐÚNG - Theme tự động
TextField(
  decoration: InputDecoration(
    labelText: 'Input',
    // Theme đã config InputDecorationTheme
  ),
)
```

---

## 📝 Danh Sách File Cần Cập Nhật

### 🔴 Ưu Tiên Cao (Core UI)

1. **lib/screens/home/home_page.dart**
   - [ ] Scaffold background
   - [ ] Container/Card colors
   - [ ] Text colors
   
2. **lib/screens/home/widgets/balance_overview.dart**
   - [ ] Card background & shadow
   - [ ] Text colors (số tiền, label)
   - [ ] Icon colors

3. **lib/screens/home/widgets/quick_actions.dart**
   - [ ] Grid item backgrounds
   - [ ] Icon & text colors
   - [ ] Ripple effect

4. **lib/screens/home/widgets/recent_transactions.dart**
   - [ ] List tile backgrounds
   - [ ] Text hierarchy colors
   - [ ] Divider colors

5. **lib/screens/transaction/transactions_screen.dart**
   - [ ] AppBar
   - [ ] List background
   - [ ] Transaction cards
   - [ ] Floating Action Button

6. **lib/screens/loan/loan_list_screen.dart**
   - [ ] Similar to transactions
   
7. **lib/screens/statistics/statistics_screen.dart**
   - [ ] Charts background
   - [ ] Card colors
   - [ ] Text colors

8. **lib/widgets/whale_navigation_bar.dart**
   - [ ] Background color
   - [ ] Selected/unselected colors
   - [ ] Icons

### 🟡 Ưu Tiên Trung Bình (Dialogs & Forms)

9. **lib/screens/add_transaction/add_transaction_page.dart**
   - [ ] Form fields
   - [ ] Buttons
   - [ ] Category selector

10. **lib/screens/add_loan/add_loan_page.dart**
    - [ ] Similar to add_transaction

### 🟢 Ưu Tiên Thấp (Đã Hoàn Thành)

11. **lib/screens/profile/profile_screen.dart** ✅
    - Đã được cập nhật đầy đủ

---

## 🚀 Template Code Mẫu

### Template Widget với Dark Mode

```dart
import 'package:flutter/material.dart';
import '../../utils/theme_helper.dart';

class MyWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // Lấy colors dễ dàng
    final colors = context.colors;
    final isDark = context.isDark;
    
    return Scaffold(
      backgroundColor: context.theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('Title'),
        // AppBar tự động dùng theme
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Card với shadow tự động
            ThemedCard(
              child: Column(
                children: [
                  Text(
                    'Title',
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Subtitle',
                    style: TextStyle(
                      color: colors.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            
            // Button
            ThemedButton(
              text: 'Action',
              icon: Icons.add,
              onPressed: () {},
            ),
          ],
        ),
      ),
    );
  }
}
```

---

## 🎨 Bảng Màu Reference

### Light Mode
| Element | Property | Color |
|---------|----------|-------|
| Background | scaffoldBackgroundColor | #F5F7FA |
| Surface | colorScheme.surface | #FFFFFF |
| Surface Variant | surfaceContainerHighest | #F0F2F5 |
| Text Primary | onSurface | #1A1A1A |
| Text Secondary | onSurfaceVariant | #757575 |
| Border | outline | #E0E0E0 |
| Shadow | shadow | rgba(0,0,0,0.1) |

### Dark Mode
| Element | Property | Color |
|---------|----------|-------|
| Background | scaffoldBackgroundColor | #121212 |
| Surface | colorScheme.surface | #1E1E1E |
| Surface Variant | surfaceContainerHighest | #2C2C2C |
| Text Primary | onSurface | #E0E0E0 |
| Text Secondary | onSurfaceVariant | #B0B0B0 |
| Border | outline | #404040 |
| Shadow | shadow | rgba(0,0,0,0.25) |

---

## 🐛 Debug Tips

### Kiểm tra widget không đổi màu:
```dart
// Thêm vào widget để debug
print('Is Dark: ${context.isDark}');
print('Surface: ${context.colorScheme.surface}');
print('OnSurface: ${context.colorScheme.onSurface}');
```

### Kiểm tra tương phản:
- Text phải có tương phản >= 4.5:1 với background
- Dùng Chrome DevTools Color Picker để kiểm tra

---

## ✅ Test Checklist

- [ ] Bật Dark Mode → Tất cả màn hình chuyển màu
- [ ] Text vẫn đọc được (không bị đè)
- [ ] Icon vẫn nhìn thấy rõ
- [ ] Card/Button có shadow/elevation rõ ràng
- [ ] Tắt Dark Mode → Có shadow như cũ
- [ ] Bottom Nav đổi màu đồng bộ
- [ ] Dialog/BottomSheet đổi màu
- [ ] TextField/Form đổi màu
- [ ] Khởi động lại app → Giữ theme

---

**Ngày cập nhật:** 25/10/2025  
**Trạng thái:** Đang triển khai  
**Ưu tiên:** 🔴 Cao

