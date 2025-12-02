import 'dart:io';
import 'dart:developer';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import '../database/database_helper.dart';

/// Service để xử lý sao lưu và khôi phục database
class BackupService {
  static final BackupService _instance = BackupService._internal();
  factory BackupService() => _instance;
  BackupService._internal();

  /// Tạo bản sao lưu database
  /// Trả về đường dẫn file backup nếu thành công
  Future<String> backupDatabase() async {
    try {
      // Lấy đường dẫn database hiện tại
      final dbHelper = DatabaseHelper();
      final db = await dbHelper.database;
      final dbPath = db.path;

      log('📂 Database path: $dbPath');

      // Đóng database trước khi copy
      await db.close();

      // Lấy thư mục Downloads hoặc Documents
      Directory? targetDirectory;

      if (Platform.isAndroid) {
        // Android: Thử lấy thư mục Downloads trước
        try {
          final externalDir = await getExternalStorageDirectory();
          if (externalDir != null) {
            // /storage/emulated/0/Android/data/package/files
            // Chuyển sang /storage/emulated/0/Download
            final downloadPath = '/storage/emulated/0/Download';
            targetDirectory = Directory(downloadPath);

            // Nếu không tồn tại hoặc không có quyền, dùng thư mục app
            if (!await targetDirectory.exists()) {
              targetDirectory = externalDir;
            }
          }
        } catch (e) {
          log('⚠️ Không thể truy cập Download folder: $e');
          targetDirectory = await getApplicationDocumentsDirectory();
        }
      } else {
        // iOS hoặc các platform khác
        targetDirectory = await getApplicationDocumentsDirectory();
      }

      if (targetDirectory == null) {
        throw Exception('Không thể xác định thư mục lưu trữ');
      }

      // Tạo tên file backup với timestamp
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').split('.')[0];
      final backupFileName = 'whales_spent_backup_$timestamp.db';
      final backupPath = join(targetDirectory.path, backupFileName);

      log('💾 Backup path: $backupPath');

      // Copy file database
      final dbFile = File(dbPath);
      await dbFile.copy(backupPath);

      // Khởi tạo lại database sau khi đóng
      await dbHelper.database;

      log('✅ Backup thành công: $backupPath');
      return backupPath;
    } catch (e) {
      log('❌ Lỗi backup database: $e');
      rethrow;
    }
  }

  /// Khôi phục database từ file backup
  Future<void> restoreDatabase(String backupPath) async {
    try {
      final backupFile = File(backupPath);

      // Kiểm tra file backup có tồn tại không
      if (!await backupFile.exists()) {
        throw Exception('File backup không tồn tại');
      }

      log('📂 Backup file path: $backupPath');

      // Lấy đường dẫn database hiện tại
      final dbHelper = DatabaseHelper();
      final db = await dbHelper.database;
      final dbPath = db.path;

      log('📂 Database path: $dbPath');

      // Đóng database trước khi thay thế
      await db.close();

      // Xóa database cũ
      final dbFile = File(dbPath);
      if (await dbFile.exists()) {
        await dbFile.delete();
        log('🗑️ Đã xóa database cũ');
      }

      // Copy file backup vào vị trí database
      await backupFile.copy(dbPath);
      log('📋 Đã copy file backup vào vị trí database');

      // Flush để đảm bảo dữ liệu được ghi vào disk
      final newDbFile = File(dbPath);
      final randomAccessFile = await newDbFile.open(mode: FileMode.append);
      await randomAccessFile.flush();
      await randomAccessFile.close();

      log('✅ Khôi phục database thành công');

      // Khởi tạo lại database
      await dbHelper.database;
    } catch (e) {
      log('❌ Lỗi khôi phục database: $e');
      rethrow;
    }
  }

  /// Lấy danh sách các file backup có sẵn
  Future<List<FileSystemEntity>> getBackupFiles() async {
    try {
      Directory? targetDirectory;

      if (Platform.isAndroid) {
        try {
          final downloadPath = '/storage/emulated/0/Download';
          targetDirectory = Directory(downloadPath);

          if (!await targetDirectory.exists()) {
            final externalDir = await getExternalStorageDirectory();
            targetDirectory = externalDir;
          }
        } catch (e) {
          targetDirectory = await getApplicationDocumentsDirectory();
        }
      } else {
        targetDirectory = await getApplicationDocumentsDirectory();
      }

      if (targetDirectory == null) {
        return [];
      }

      // Lọc các file .db có tên bắt đầu bằng "whales_spent_backup"
      final files = targetDirectory
          .listSync()
          .where((file) =>
              file.path.endsWith('.db') &&
              basename(file.path).startsWith('whales_spent_backup'))
          .toList();

      // Sắp xếp theo thời gian modified (mới nhất trước)
      files.sort((a, b) {
        final aStat = a.statSync();
        final bStat = b.statSync();
        return bStat.modified.compareTo(aStat.modified);
      });

      return files;
    } catch (e) {
      log('❌ Lỗi lấy danh sách backup files: $e');
      return [];
    }
  }

  /// Xóa file backup
  Future<void> deleteBackupFile(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
        log('✅ Đã xóa file backup: $filePath');
      }
    } catch (e) {
      log('❌ Lỗi xóa file backup: $e');
      rethrow;
    }
  }

  /// Lấy kích thước database hiện tại
  Future<int> getDatabaseSize() async {
    try {
      final dbHelper = DatabaseHelper();
      final db = await dbHelper.database;
      final dbFile = File(db.path);

      if (await dbFile.exists()) {
        return await dbFile.length();
      }
      return 0;
    } catch (e) {
      log('❌ Lỗi lấy kích thước database: $e');
      return 0;
    }
  }

  /// Format kích thước file thành chuỗi dễ đọc
  String formatFileSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(2)} KB';
    } else {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    }
  }
}

