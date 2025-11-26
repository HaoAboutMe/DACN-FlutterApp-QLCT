import 'dart:io';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// 🧾 Receipt OCR Service - Quét bill và lấy số tiền thanh toán
///
/// Service này dùng Google ML Kit để quét mọi loại hóa đơn (siêu thị, nhà hàng,
/// Grab/Gojek, điện tử...) và extract chính xác số tiền cần thanh toán.
///
/// ✔ Bỏ qua các số rác: giá từng món, số cân, ngày tháng, mã HĐ, hotline, tiền thối...
/// ✔ Ưu tiên keyword: "Thanh toán" > "Tổng tiền" > "Total"
/// ✔ Xử lý keyword tách dòng (keyword ở dòng trên, số tiền ở dòng dưới)
/// ✔ Làm tròn theo chuẩn VN (≥500 → lên, <500 → xuống)
/// ✔ Logic số học tự động chọn số hợp lý nhất

class ReceiptOcrResult {
  final double? totalAmount; // Số tiền cuối cùng đã chọn
  final Map<String, double> candidates; // Debug: xem service chọn gì
  final String rawText; // Văn bản gốc

  ReceiptOcrResult({
    required this.totalAmount,
    required this.candidates,
    required this.rawText,
  });
}

class _OcrCandidate {
  final String line; // Dòng gốc
  final double value; // Số tiền
  final int priority; // 1=thanh toán (cao nhất), 2=tổng tiền, 3=thành tiền, 999=khác
  final int lineIndex; // Vị trí dòng trong văn bản gốc


  _OcrCandidate({
    required this.line,
    required this.value,
    required this.priority,
    required this.lineIndex,
  });
}

class ReceiptOcrService {
  final TextRecognizer _textRecognizer = TextRecognizer();

  // Hàm quét và đưa ra số tiền
  Future<ReceiptOcrResult> processImage(File imageFile) async {
    final inputImage = InputImage.fromFile(imageFile); // Đọc file ảnh
    final recognizedText = await _textRecognizer.processImage(inputImage); // Quét ảnh

    final rawText = recognizedText.text; // gán rawText là text được quét từ ảnh
    final lines = rawText.split('\n'); // tách ra từng dòng

    final candidates = <_OcrCandidate>[]; // Danh sách các candidate
    final debugMap = <String, double>{}; // Debug: xem service chọn gì


    // ═══════════════════════════════════════════════════════════════════
    // BƯỚC 1: PHÂN TÍCH TỪNG DÒNG & LỌC RÁC
    // Quét từng dòng sau đó normalize (lowercase, bỏ dấu, clean)
    // ═══════════════════════════════════════════════════════════════════

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;

      final normalized = _normalize(line);

      // ───────────────────────────────────────────────────────────────
      // 🚫 BỎ QUA CÁC DÒNG RÁC (BLACKLIST)
      // ───────────────────────────────────────────────────────────────

      // Skip: Mã HĐ, số CT, invoice, barcode, MST
      if (_hasKeyword(normalized, [
        'ma hoa don', 'ma don', 'so hoa don', 'so ct', 'invoice',
        'bill no', 'receipt no', 'order', 'ma don hang',
        'mst', 'ma so thue', 'tax code', 'barcode', 'ma vach'
      ])) continue;

      // Skip: Hotline, tổng đài, điện thoại, fax
      if (_hasKeyword(normalized, [
        'hotline', 'tong dai', 'lien he', 'dien thoai', 'phone',
        'tel', 'fax', 'mobile', 'contact', 'call'
      ])) continue;

      // Skip: Tiền mặt khách đưa
      if (_hasKeyword(normalized, [
        'tien mat', 'khach dua', 'khach tra', 'customer pay',
        'cash', 'received', 'given', 'tien nhan', 'nhan tien'
      ])) continue;

      // Skip: Tiền thừa / tiền thối / tiền trả lại
      if (_hasKeyword(normalized, [
        'tien thua', 'tien thoi', 'thoi lai', 'tra lai', 'change',
        'tien du', 'con lai', 'du thua'
      ])) continue;

      // Skip: Ngày tháng, thời gian
      if (_hasKeyword(normalized, [
        'ngay', 'thang', 'nam', 'date', 'time', 'gio', 'phut'
      ]) && !_hasKeyword(normalized, ['tong', 'thanh', 'total'])) {
        continue;
      }

      // Skip: Số bàn, STT, số thứ tự
      if (_hasKeyword(normalized, [
        'so ban', 'table', 'stt', 'thu tu', 'queue'
      ])) continue;

      // Skip: Số cân nặng (chứa 'kg', 'g', hoặc số nhỏ < 100)
      if (normalized.contains('kg') || normalized.contains(' g ')) continue;

      // ───────────────────────────────────────────────────────────────
      // 💰 EXTRACT SỐ TIỀN TỪ DÒNG
      // ───────────────────────────────────────────────────────────────

      final amount = _extractAmount(line);
      if (amount == null) continue;

      // ───────────────────────────────────────────────────────────────
      // 🚫 LOẠI CÁC SỐ KHÔNG HỢP LỆ
      // ───────────────────────────────────────────────────────────────

      // Loại số quá nhỏ (< 1000) hoặc quá lớn (> 100 triệu)
      if (amount < 1000 || amount > 100000000) continue;

      // Loại số năm (1900-2100) - Đặc biệt quan trọng cho "Đã thanh toán 18 thg 6 2020"
      // VD: "Đã thanh toán 18 thg 6 2020" → OCR bắt 2020 → service coi là 2000đ ❌
      if (amount >= 1900 && amount <= 2100) {
        // Chỉ skip nếu dòng CÓ keyword ngày tháng hoặc "đã thanh toán"
        if (_hasKeyword(normalized, [
          'thg', 'month', 'ngay', 'date', 'da thanh toan', 'paid on'
        ])) {
          continue; // ✅ Skip số năm trong context ngày tháng
        }
      }

      // ───────────────────────────────────────────────────────────────
      // 🎯 GÁN PRIORITY DỰA VÀO KEYWORD
      // ───────────────────────────────────────────────────────────────

      int priority = 999;

      // Priority 1: "THANH TOÁN" (cao nhất - số tiền đã làm tròn)
      if (_hasKeyword(normalized, [
        'thanh toan', 'amount due', 'to pay', 'amount to pay',
        'payment', 'pay amount', 'can thanh toan'
      ])) {
        priority = 1;
      }
      // Priority 2: "TỔNG TIỀN" / "TỔNG CỘNG" / "GRAND TOTAL"
      else if (_hasKeyword(normalized, [
        'tong tien', 'tong cong', 'grand total', 'final total',
        'net total', 'total amount'
      ])) {
        priority = 2;
      }
      // Priority 3: "TOTAL" đơn thuần hoặc "THÀNH TIỀN"
      else if (_hasKeyword(normalized, [
        'total', 'thanh tien', 'sum', 'subtotal'
      ])) {
        priority = 3;
      }

      candidates.add(_OcrCandidate(
        line: line,
        value: amount,
        priority: priority,
        lineIndex: i,
      ));
    }

    // ═══════════════════════════════════════════════════════════════════
    // BƯỚC 2: XỬ LÝ KEYWORD TÁCH DÒNG (keyword ở dòng trên, số ở dòng dưới)
    // ═══════════════════════════════════════════════════════════════════

    for (int i = 0; i < lines.length - 1; i++) {
      final currentLine = _normalize(lines[i]);
      final nextLine = lines[i + 1].trim();

      // Nếu dòng hiện tại có keyword quan trọng NHƯNG KHÔNG CÓ SỐ
      if (_hasKeyword(currentLine, [
        'thanh toan', 'tong tien', 'tong cong', 'total', 'amount due'
      ])) {
        final currentAmount = _extractAmount(lines[i]);

        // Và dòng kế tiếp CÓ SỐ
        if (currentAmount == null) {
          final nextAmount = _extractAmount(nextLine);
          if (nextAmount != null && nextAmount >= 1000 && nextAmount <= 100000000) {
            // Kiểm tra xem số này đã được add chưa
            final alreadyExists = candidates.any(
              (c) => c.lineIndex == i + 1 && c.value == nextAmount
            );

            if (!alreadyExists) {
              int priority = 999;
              if (_hasKeyword(currentLine, ['thanh toan', 'amount due'])) {
                priority = 1;
              } else if (_hasKeyword(currentLine, ['tong tien', 'tong cong', 'grand total'])) {
                priority = 2;
              } else if (_hasKeyword(currentLine, ['total'])) {
                priority = 3;
              }

              candidates.add(_OcrCandidate(
                line: '${lines[i]} → $nextLine',
                value: nextAmount,
                priority: priority,
                lineIndex: i + 1,
              ));
            }
          }
        }
      }
    }

    if (candidates.isEmpty) {
      return ReceiptOcrResult(
        totalAmount: null,
        candidates: {},
        rawText: rawText,
      );
    }

    // ═══════════════════════════════════════════════════════════════════
    // BƯỚC 3: CHỌN SỐ TỐT NHẤT
    // ═══════════════════════════════════════════════════════════════════

    // Phân loại theo priority
    final p1List = candidates.where((c) => c.priority == 1).toList(); // Thanh toán
    final p2List = candidates.where((c) => c.priority == 2).toList(); // Tổng tiền
    final p3List = candidates.where((c) => c.priority == 3).toList(); // Total/Thành tiền
    final othersList = candidates.where((c) => c.priority == 999).toList();

    double? bestAmount;

    // ─────────────────────────────────────────────────────────────────
    // 🥇 PRIORITY 1: "THANH TOÁN" (ưu tiên tuyệt đối)
    // ─────────────────────────────────────────────────────────────────
    if (p1List.isNotEmpty) {
      // Nếu có nhiều số "Thanh toán", lấy số ở dòng dưới cùng
      p1List.sort((a, b) => b.lineIndex.compareTo(a.lineIndex));
      final best = p1List.first;
      bestAmount = best.value;

      for (final c in p1List) {
        debugMap['[P1-THANH_TOAN][line${c.lineIndex}] ${c.line}'] = c.value;
      }

      // Làm tròn nếu cần (theo chuẩn VN: ≥500 → lên, <500 → xuống)
      bestAmount = _roundToNearest1000(bestAmount);

      return ReceiptOcrResult(
        totalAmount: bestAmount,
        candidates: debugMap,
        rawText: rawText,
      );
    }

    // ─────────────────────────────────────────────────────────────────
    // 🥈 PRIORITY 2: "TỔNG TIỀN" / "TỔNG CỘNG" / "GRAND TOTAL"
    // ─────────────────────────────────────────────────────────────────
    if (p2List.isNotEmpty) {
      p2List.sort((a, b) => b.lineIndex.compareTo(a.lineIndex));
      final best = p2List.first;
      bestAmount = best.value;

      for (final c in p2List) {
        debugMap['[P2-TONG_TIEN][line${c.lineIndex}] ${c.line}'] = c.value;
      }

      bestAmount = _roundToNearest1000(bestAmount);

      return ReceiptOcrResult(
        totalAmount: bestAmount,
        candidates: debugMap,
        rawText: rawText,
      );
    }

    // ─────────────────────────────────────────────────────────────────
    // 🥉 PRIORITY 3: "TOTAL" / "THÀNH TIỀN"
    // ─────────────────────────────────────────────────────────────────
    if (p3List.isNotEmpty) {
      p3List.sort((a, b) => b.lineIndex.compareTo(a.lineIndex));
      final best = p3List.first;
      bestAmount = best.value;

      for (final c in p3List) {
        debugMap['[P3-TOTAL][line${c.lineIndex}] ${c.line}'] = c.value;
      }

      bestAmount = _roundToNearest1000(bestAmount);

      return ReceiptOcrResult(
        totalAmount: bestAmount,
        candidates: debugMap,
        rawText: rawText,
      );
    }

    // ─────────────────────────────────────────────────────────────────
    // 🔄 FALLBACK: LOGIC SỐ HỌC (khi không có keyword rõ ràng)
    // ─────────────────────────────────────────────────────────────────
    if (othersList.isNotEmpty) {
      final values = othersList.map((c) => c.value).toList()..sort();

      // Nếu có ≥2 số, kiểm tra số lớn nhất có phải "tiền khách đưa" không
      if (values.length >= 2) {
        final max = values.last;
        final secondMax = values[values.length - 2];

        // Nếu max - secondMax > 50k → max có thể là tiền khách đưa → bỏ max
        if (max - secondMax > 50000) {
          othersList.removeWhere((c) => c.value == max);
          values.removeLast();
        }
      }

      // Lấy số lớn nhất còn lại
      if (othersList.isNotEmpty) {
        othersList.sort((a, b) => b.value.compareTo(a.value));
        bestAmount = othersList.first.value;

        for (final c in othersList) {
          debugMap['[FALLBACK][line${c.lineIndex}] ${c.line}'] = c.value;
        }

        bestAmount = _roundToNearest1000(bestAmount);
      }
    }

    return ReceiptOcrResult(
      totalAmount: bestAmount,
      candidates: debugMap,
      rawText: rawText,
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // ═══════════════════ HELPER FUNCTIONS ══════════════════════════════
  // ═══════════════════════════════════════════════════════════════════

  /// Extract số tiền từ dòng text
  /// Ví dụ: "Tổng tiền: 322,000 VND" → 322000
  double? _extractAmount(String line) {
    // Pattern: Số có dấu phân cách (1.000 hoặc 1,000) hoặc số liền ≥3 chữ số
    final regex = RegExp(r'(\d{1,3}(?:[.,]\d{3})+|\d{3,})');

    final matches = regex.allMatches(line);
    if (matches.isEmpty) return null;

    // Lấy số CUỐI CÙNG trong dòng (thường là số tiền)
    final match = matches.last;
    String numberStr = match.group(0)!;

    // Chỉ lấy chữ số
    final digitsOnly = numberStr.replaceAll(RegExp(r'[^0-9]'), '');

    // Loại số quá dài (>10 chữ số = barcode/hotline)
    if (digitsOnly.length > 10) return null;

    // Loại số quá ngắn (<3 chữ số = STT/số lượng)
    if (digitsOnly.length < 3) return null;

    final value = double.tryParse(digitsOnly);
    if (value == null || value <= 0) return null;

    return value;
  }

  /// Normalize text: lowercase + bỏ dấu + bỏ ký tự đặc biệt
  String _normalize(String text) {
    text = text.toLowerCase();
    text = _removeAccent(text);
    // Giữ lại số, chữ, khoảng trắng
    text = text.replaceAll(RegExp(r'[^a-z0-9 ]'), ' ');
    // Xóa khoảng trắng thừa
    text = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    return text;
  }

  /// Kiểm tra text có chứa bất kỳ keyword nào không
  bool _hasKeyword(String text, List<String> keywords) {
    for (final keyword in keywords) {
      final normalizedKeyword = _removeAccent(keyword.toLowerCase());
      if (text.contains(normalizedKeyword)) {
        return true;
      }
    }
    return false;
  }

  /// Làm tròn số tiền về bội số 1000 (chuẩn VN)
  /// ≥500 → làm tròn lên, <500 → làm tròn xuống
  double _roundToNearest1000(double amount) {
    final remainder = amount % 1000;

    // Nếu đã là bội số 1000, không cần làm tròn
    if (remainder == 0) return amount;

    // Nếu phần dư < 200 → làm tròn xuống (có thể là lỗi OCR)
    if (remainder < 200) {
      return amount - remainder;
    }

    // Nếu phần dư ≥ 500 → làm tròn lên
    if (remainder >= 500) {
      return amount - remainder + 1000;
    }

    // Nếu 200 ≤ phần dư < 500 → giữ nguyên (số thực tế)
    return amount;
  }

  /// Bỏ dấu tiếng Việt
  String _removeAccent(String text) {
    const vietnameseMap = {
      'à': 'a', 'á': 'a', 'ạ': 'a', 'ả': 'a', 'ã': 'a',
      'â': 'a', 'ầ': 'a', 'ấ': 'a', 'ậ': 'a', 'ẩ': 'a', 'ẫ': 'a',
      'ă': 'a', 'ằ': 'a', 'ắ': 'a', 'ặ': 'a', 'ẳ': 'a', 'ẵ': 'a',
      'è': 'e', 'é': 'e', 'ẹ': 'e', 'ẻ': 'e', 'ẽ': 'e',
      'ê': 'e', 'ề': 'e', 'ế': 'e', 'ệ': 'e', 'ể': 'e', 'ễ': 'e',
      'ì': 'i', 'í': 'i', 'ị': 'i', 'ỉ': 'i', 'ĩ': 'i',
      'ò': 'o', 'ó': 'o', 'ọ': 'o', 'ỏ': 'o', 'õ': 'o',
      'ô': 'o', 'ồ': 'o', 'ố': 'o', 'ộ': 'o', 'ổ': 'o', 'ỗ': 'o',
      'ơ': 'o', 'ờ': 'o', 'ớ': 'o', 'ợ': 'o', 'ở': 'o', 'ỡ': 'o',
      'ù': 'u', 'ú': 'u', 'ụ': 'u', 'ủ': 'u', 'ũ': 'u',
      'ư': 'u', 'ừ': 'u', 'ứ': 'u', 'ự': 'u', 'ử': 'u', 'ữ': 'u',
      'ỳ': 'y', 'ý': 'y', 'ỵ': 'y', 'ỷ': 'y', 'ỹ': 'y',
      'đ': 'd'
    };

    return text.split('').map((char) => vietnameseMap[char] ?? char).join('');
  }

  /// Dispose TextRecognizer khi không dùng nữa
  Future<void> dispose() async {
    await _textRecognizer.close();
  }
}

