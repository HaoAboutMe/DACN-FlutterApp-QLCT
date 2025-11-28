import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:app_qlct/services/receipt_ocr_service.dart';
import 'package:app_qlct/database/repositories/repositories.dart';
import 'package:app_qlct/screens/add_transaction/add_transaction_page.dart';

class ReceiptScanScreen extends StatefulWidget {
  const ReceiptScanScreen({super.key});

  @override
  State<ReceiptScanScreen> createState() => _ReceiptScanScreenState();
}

class _ReceiptScanScreenState extends State<ReceiptScanScreen> {
  final ImagePicker _picker = ImagePicker();
  final ReceiptOcrService _ocrService = ReceiptOcrService();
  final CategoryRepository _categoryRepository = CategoryRepository();

  File? _imageFile;
  double? _amount;
  String? _debugText;
  bool _isLoading = false;

  Future<void> _pickImage(ImageSource source) async {
    final pickedFile = await _picker.pickImage(
      source: source,
      imageQuality: 85,
    );

    if (pickedFile == null) return;

    setState(() {
      _imageFile = File(pickedFile.path);
      _amount = null;
      _debugText = null;
    });

    await _runOcr();
  }

  Future<void> _runOcr() async {
    if (_imageFile == null) return;

    setState(() => _isLoading = true);

    final result = await _ocrService.processImage(_imageFile!);

    setState(() {
      _isLoading = false;
      _amount = result.totalAmount;
      _debugText = result.rawText;
    });
  }

  Future<void> _useDetectedAmount() async {
    if (_amount == null) return;

    try {
      // Hiển thị loading bằng setState thay vì dialog
      setState(() => _isLoading = true);

      // Tìm hoặc tạo danh mục "Hóa đơn"
      final receiptCategory = await _categoryRepository.findOrCreateReceiptCategory();

      // Tắt loading
      if (!mounted) return;
      setState(() => _isLoading = false);

      // Đợi một chút để setState hoàn thành và widget rebuild xong
      await Future.delayed(const Duration(milliseconds: 100));

      if (!mounted) return;

      // Mở AddTransactionPage với dữ liệu đã điền sẵn
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => AddTransactionPage(
            preselectedType: 'expense',
            preselectedCategoryId: receiptCategory.id,
            initialAmount: _amount,
            preselectedDescription: 'Hóa đơn',
          ),
        ),
      );

      // Nếu transaction được thêm thành công, quay về Home và báo cần reload
      if (result == true && mounted) {
        // Pop về màn hình trước (Home) với signal để reload
        Navigator.pop(context, true);
      }
    } catch (e) {
      // Tắt loading và hiển thị lỗi
      if (mounted) {
        setState(() => _isLoading = false);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _ocrService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
            'Quét hóa đơn',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
        ),
        backgroundColor: isDark ? theme.scaffoldBackgroundColor : colorScheme.primary,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FilledButton.icon(
                onPressed: () => _pickImage(ImageSource.camera),
                icon: const Icon(Icons.camera_alt),
                label: const Text('Camera'),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: () => _pickImage(ImageSource.gallery),
                icon: const Icon(Icons.photo_library),
                label: const Text('Thư viện'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_imageFile != null)
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    Image.file(_imageFile!),
                    const SizedBox(height: 16),
                    if (_isLoading)
                      const CircularProgressIndicator()
                    else if (_amount != null)
                      Column(
                        children: [
                          Text(
                            'Số tiền phát hiện: ${_amount!.toStringAsFixed(0)} đ',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          FilledButton(
                            onPressed: _isLoading ? null : _useDetectedAmount,
                            child: _isLoading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Text('Dùng số tiền này'),
                          ),
                        ],
                      )
                    else
                      const Text('Không tìm được số tiền phù hợp'),
                    const SizedBox(height: 16),
                    ExpansionTile(
                      title: const Text('Xem raw OCR'),
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Text(_debugText ?? ''),
                        ),
                      ],
                    )
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
