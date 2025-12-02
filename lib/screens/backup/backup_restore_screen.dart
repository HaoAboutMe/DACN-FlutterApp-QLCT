import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;
import '../../services/backup_service.dart';

/// Màn hình Sao lưu & Khôi phục dữ liệu
class BackupRestoreScreen extends StatefulWidget {
  const BackupRestoreScreen({super.key});

  @override
  State<BackupRestoreScreen> createState() => _BackupRestoreScreenState();
}

class _BackupRestoreScreenState extends State<BackupRestoreScreen> {
  final BackupService _backupService = BackupService();

  String? _backupPath;
  String? _selectedFile;
  bool _isLoading = false;
  int _databaseSize = 0;
  List<FileSystemEntity> _backupFiles = [];

  @override
  void initState() {
    super.initState();
    _loadDatabaseInfo();
    _loadBackupFiles();
  }

  Future<void> _loadDatabaseInfo() async {
    final size = await _backupService.getDatabaseSize();
    setState(() {
      _databaseSize = size;
    });
  }

  Future<void> _loadBackupFiles() async {
    final files = await _backupService.getBackupFiles();
    setState(() {
      _backupFiles = files;
    });
  }

  Future<void> _createBackup() async {
    setState(() {
      _isLoading = true;
      _backupPath = null;
    });

    try {
      final backupPath = await _backupService.backupDatabase();

      setState(() {
        _backupPath = backupPath;
        _isLoading = false;
      });

      // Reload backup files list
      await _loadBackupFiles();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Sao lưu thành công!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: 'Xem',
              textColor: Colors.white,
              onPressed: () {
                _showBackupPathDialog(backupPath);
              },
            ),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Lỗi sao lưu: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _pickBackupFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['db'],
      );

      if (result != null && result.files.single.path != null) {
        setState(() {
          _selectedFile = result.files.single.path;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Lỗi chọn file: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _restoreFromFile() async {
    if (_selectedFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Vui lòng chọn file backup trước'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final confirmed = await _showRestoreConfirmDialog();
    if (!confirmed) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await _backupService.restoreDatabase(_selectedFile!);

      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        _showRestartDialog();
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Lỗi khôi phục: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _restoreFromBackupList(String filePath) async {
    final confirmed = await _showRestoreConfirmDialog();
    if (!confirmed) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await _backupService.restoreDatabase(filePath);

      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        _showRestartDialog();
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Lỗi khôi phục: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<bool> _showRestoreConfirmDialog() async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange),
            SizedBox(width: 8),
            Text('Xác nhận khôi phục'),
          ],
        ),
        content: const Text(
          'Khôi phục dữ liệu sẽ ghi đè toàn bộ dữ liệu hiện tại. '
          'Bạn có chắc chắn muốn tiếp tục?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: const Text('Khôi phục'),
          ),
        ],
      ),
    ) ?? false;
  }

  void _showRestartDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 8),
            Text('Khôi phục thành công'),
          ],
        ),
        content: const Text(
          'Dữ liệu đã được khôi phục thành công!\n\n'
          'Vui lòng khởi động lại ứng dụng để áp dụng thay đổi.',
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              // Close app
              exit(0);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF5D5FEF),
              foregroundColor: Colors.white,
            ),
            child: const Text('Đóng ứng dụng'),
          ),
        ],
      ),
    );
  }

  void _showBackupPathDialog(String path) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Đường dẫn file backup'),
        content: SelectableText(path),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteBackupFile(String filePath) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: Text('Bạn có chắc muốn xóa file backup:\n${path.basename(filePath)}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Xóa'),
          ),
        ],
      ),
    ) ?? false;

    if (!confirmed) return;

    try {
      await _backupService.deleteBackupFile(filePath);
      await _loadBackupFiles();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Đã xóa file backup'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Lỗi xóa file: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sao lưu & Khôi phục'),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Đang xử lý...'),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _buildDatabaseInfoCard(isDark),
                const SizedBox(height: 20),
                _buildBackupCard(isDark),
                const SizedBox(height: 20),
                _buildRestoreCard(isDark),
                const SizedBox(height: 20),
                _buildBackupListCard(isDark),
              ],
            ),
    );
  }

  Widget _buildDatabaseInfoCard(bool isDark) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
              Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF5D5FEF).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.info_outline,
                    color: Color(0xFF5D5FEF),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'THÔNG TIN DATABASE',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Kích thước database:',
                  style: TextStyle(fontSize: 14),
                ),
                Text(
                  _backupService.formatFileSize(_databaseSize),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF5D5FEF),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBackupCard(bool isDark) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.backup_outlined,
                    color: Colors.green,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'SAO LƯU DỮ LIỆU',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Tạo bản sao lưu dữ liệu để bảo vệ thông tin của bạn',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _createBackup,
                icon: const Icon(Icons.save_alt),
                label: const Text('Tạo bản sao lưu'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            if (_backupPath != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.green.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.green, size: 16),
                        SizedBox(width: 6),
                        Text(
                          'File đã được lưu tại:',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _backupPath!,
                      style: const TextStyle(
                        fontSize: 11,
                        fontFamily: 'monospace',
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRestoreCard(bool isDark) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.restore_outlined,
                    color: Colors.orange,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'KHÔI PHỤC DỮ LIỆU',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Khôi phục dữ liệu từ file backup đã lưu',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _pickBackupFile,
                icon: const Icon(Icons.folder_open),
                label: const Text('Chọn file .db để khôi phục'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF5D5FEF),
                  side: const BorderSide(color: Color(0xFF5D5FEF)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            if (_selectedFile != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF5D5FEF).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFF5D5FEF).withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.insert_drive_file,
                      color: Color(0xFF5D5FEF),
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        path.basename(_selectedFile!),
                        style: const TextStyle(fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _restoreFromFile,
                  icon: const Icon(Icons.restore),
                  label: const Text('Khôi phục dữ liệu'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBackupListCard(bool isDark) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF5D5FEF).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.history,
                        color: Color(0xFF5D5FEF),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'CÁC BẢN SAO LƯU',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  onPressed: _loadBackupFiles,
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Làm mới',
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_backupFiles.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: Text(
                    'Chưa có bản sao lưu nào',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 14,
                    ),
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _backupFiles.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final file = _backupFiles[index];
                  final fileName = path.basename(file.path);
                  final fileStat = file.statSync();
                  final fileSize = _backupService.formatFileSize(fileStat.size);
                  final modifiedDate = fileStat.modified;

                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    leading: const Icon(
                      Icons.insert_drive_file,
                      color: Color(0xFF5D5FEF),
                    ),
                    title: Text(
                      fileName,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      '$fileSize • ${_formatDate(modifiedDate)}',
                      style: const TextStyle(fontSize: 11),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          onPressed: () => _restoreFromBackupList(file.path),
                          icon: const Icon(Icons.restore, color: Colors.orange),
                          tooltip: 'Khôi phục',
                        ),
                        IconButton(
                          onPressed: () => _deleteBackupFile(file.path),
                          icon: const Icon(Icons.delete, color: Colors.red),
                          tooltip: 'Xóa',
                        ),
                      ],
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year} '
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }
}

