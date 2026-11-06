import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/database/app_database.dart';

class BackupService {
  Future<File> createBackup() async {
    final dbPath = await AppDatabase.instance.path;
    final directory = await getTemporaryDirectory();
    final stamp = DateFormat('yyyyMMdd-HHmm').format(DateTime.now());
    final file = File(p.join(directory.path, 'novus-respaldo-$stamp.db'));

    await AppDatabase.instance.close();
    try {
      await File(dbPath).copy(file.path);
    } finally {
      await AppDatabase.instance.reopen();
    }

    return file;
  }

  Future<File> shareBackup() async {
    final file = await createBackup();
    await Share.shareXFiles(
      [XFile(file.path)],
      subject: 'Respaldo Novus',
      text: 'Respaldo de Novus generado el '
          '${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
    );
    return file;
  }

  Future<File?> pickBackupFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: false,
      withData: false,
    );

    final path = result?.files.single.path;
    if (path == null) return null;
    return File(path);
  }

  Future<void> restore(File source) async {
    final bytes = await source.readAsBytes();
    final header = bytes.length >= 16
        ? String.fromCharCodes(bytes.sublist(0, 15))
        : '';
    if (header != 'SQLite format 3') {
      throw Exception('El archivo no es un respaldo válido de Novus');
    }

    final dbPath = await AppDatabase.instance.path;
    await AppDatabase.instance.close();
    try {
      await source.copy(dbPath);
      for (final suffix in ['-journal', '-wal', '-shm']) {
        final file = File('$dbPath$suffix');
        if (await file.exists()) {
          await file.delete();
        }
      }
    } finally {
      await AppDatabase.instance.reopen();
    }
  }
}
