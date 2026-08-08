import 'dart:io';

import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

class AppLog {
  static const int maxBytes = 1024 * 1024;
  static var fileName = "runlog.log";

  static Future<String> logPath() async {
    final dir = await getApplicationDocumentsDirectory();
    return join(dir.path, fileName);
  }

  static Future<String> rotatedLogPath() async {
    return "${await logPath()}.1";
  }

  static Future<void> write(String message) async {
    try {
      final path = await logPath();
      final file = File(path);
      await _rotateIfNeeded(file);
      final line = "${DateTime.now().toIso8601String()} $message\n";
      await file.writeAsString(line, mode: FileMode.append, flush: true);
    } catch (e) {
      print("AppLog failed to write: $e");
    }
  }

  static Future<void> _rotateIfNeeded(File file) async {
    if (!await file.exists()) {
      return;
    }
    final length = await file.length();
    if (length < maxBytes) {
      return;
    }
    final rotated = File(await rotatedLogPath());
    if (await rotated.exists()) {
      await rotated.delete();
    }
    await file.rename(rotated.path);
  }

  static Future<String> readAll() async {
    final buffer = StringBuffer();
    final rotated = File(await rotatedLogPath());
    if (await rotated.exists()) {
      buffer.write(await rotated.readAsString());
    }
    final current = File(await logPath());
    if (await current.exists()) {
      buffer.write(await current.readAsString());
    }
    return buffer.toString();
  }
}
