import 'dart:async';
import 'dart:io';

import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import 'package:run_log/app_log.dart';
import 'package:run_log/storage.dart';

class SnapshotInfo {
  final String path;
  final DateTime timestamp;
  final int runCount;

  SnapshotInfo({
    required this.path,
    required this.timestamp,
    required this.runCount,
  });

  String get fileName => basename(path);
}

class AppBackup {
  static final RegExp _pattern = RegExp(
    r'^running_log-(\d{4})-(\d{2})-(\d{2})-(\d{2})(\d{2})(\d{2})-r(\d+)(?:-(\d+))?\.db$',
  );

  static Future<String> snapshotDir() async {
    final dir = await getApplicationDocumentsDirectory();
    final snapshotDir = Directory(join(dir.path, 'snapshots'));
    if (!await snapshotDir.exists()) {
      await snapshotDir.create(recursive: true);
    }
    return snapshotDir.path;
  }

  static String _fileNameFor(DateTime ts, int runCount, {int? dedupe}) {
    final y = ts.year.toString().padLeft(4, '0');
    final mo = ts.month.toString().padLeft(2, '0');
    final d = ts.day.toString().padLeft(2, '0');
    final h = ts.hour.toString().padLeft(2, '0');
    final mi = ts.minute.toString().padLeft(2, '0');
    final s = ts.second.toString().padLeft(2, '0');
    final suffix = dedupe == null ? '' : '-$dedupe';
    return "running_log-$y-$mo-$d-$h$mi$s-r$runCount$suffix.db";
  }

  static SnapshotInfo? _parse(String path) {
    final match = _pattern.firstMatch(basename(path));
    if (match == null) {
      return null;
    }
    final year = int.parse(match.group(1)!);
    final month = int.parse(match.group(2)!);
    final day = int.parse(match.group(3)!);
    final hour = int.parse(match.group(4)!);
    final minute = int.parse(match.group(5)!);
    final second = int.parse(match.group(6)!);
    final runCount = int.parse(match.group(7)!);
    return SnapshotInfo(
      path: path,
      timestamp: DateTime(year, month, day, hour, minute, second),
      runCount: runCount,
    );
  }

  static Future<List<SnapshotInfo>> listSnapshots() async {
    final dirPath = await snapshotDir();
    final dir = Directory(dirPath);
    final entries = await dir.list().toList();
    final snaps = <SnapshotInfo>[];
    for (final entry in entries) {
      if (entry is! File) {
        continue;
      }
      final info = _parse(entry.path);
      if (info != null) {
        snaps.add(info);
      }
    }
    snaps.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return snaps;
  }

  static Future<int> _countRuns(Database db) async {
    final result = await db.rawQuery('SELECT COUNT(*) FROM Runs');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  static Future<void> _checkpoint(Database db) async {
    try {
      await db.execute('PRAGMA wal_checkpoint(TRUNCATE)');
    } catch (e) {
      await AppLog.write("wal_checkpoint skipped (not WAL?): $e");
    }
  }

  static Future<String?> createSnapshot(
    Database db, {
    required bool force,
  }) async {
    final runCount = await _countRuns(db);
    final existing = await listSnapshots();

    final hasNonEmpty = existing.any((s) => s.runCount > 0);
    if (runCount == 0 && hasNonEmpty) {
      await AppLog.write(
        "Snapshot skipped: 0 runs but a non-empty snapshot already exists",
      );
      return null;
    }

    if (!force) {
      final now = DateTime.now();
      final sameDay = existing.any(
        (s) =>
            s.timestamp.year == now.year &&
            s.timestamp.month == now.month &&
            s.timestamp.day == now.day,
      );
      if (sameDay) {
        await AppLog.write("Snapshot skipped: already have one for today");
        return null;
      }
    }

    await _checkpoint(db);

    final dbFilePath = db.path;
    final dirPath = await snapshotDir();
    var fileName = _fileNameFor(DateTime.now(), runCount);
    var destPath = join(dirPath, fileName);
    // Same-second, same-count snapshots (e.g. import immediately followed by
    // a forced snapshot) would otherwise collide on filename and silently
    // overwrite an earlier snapshot.
    int dedupe = 1;
    while (await File(destPath).exists()) {
      fileName = _fileNameFor(DateTime.now(), runCount, dedupe: dedupe);
      destPath = join(dirPath, fileName);
      dedupe++;
    }
    final tmpPath = "$destPath.tmp";

    await _copyDbFiles(dbFilePath, tmpPath);
    await File(tmpPath).rename(destPath);
    for (final suffix in ['-wal', '-shm']) {
      final tmpSide = File("$tmpPath$suffix");
      if (await tmpSide.exists()) {
        await tmpSide.rename("$destPath$suffix");
      }
    }

    await AppLog.write("Snapshot created: $fileName ($runCount runs)");
    await prune();
    return destPath;
  }

  static Future<void> _copyDbFiles(String srcPath, String destPath) async {
    await File(srcPath).copy(destPath);
    for (final suffix in ['-wal', '-shm']) {
      final side = File("$srcPath$suffix");
      if (await side.exists()) {
        await side.copy("$destPath$suffix");
      }
    }
  }

  /// The single snapshot protected from eviction: highest run count,
  /// newest among ties. Returns null for an empty list.
  static String? protectedPath(List<SnapshotInfo> snaps) {
    if (snaps.isEmpty) {
      return null;
    }
    int maxCount = -1;
    for (final s in snaps) {
      if (s.runCount > maxCount) {
        maxCount = s.runCount;
      }
    }
    final biggestCandidates =
        snaps.where((s) => s.runCount == maxCount).toList()
          ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return biggestCandidates.first.path;
  }

  static Future<void> prune() async {
    final snaps = await listSnapshots();
    if (snaps.length <= 5) {
      return;
    }

    final protectedSnapshotPath = protectedPath(snaps)!;

    final remainder =
        snaps.where((s) => s.path != protectedSnapshotPath).toList()
          ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    final toKeep = <String>{protectedSnapshotPath};
    toKeep.addAll(remainder.take(4).map((s) => s.path));

    for (final s in snaps) {
      if (!toKeep.contains(s.path)) {
        await _deleteSnapshotFiles(s.path);
        await AppLog.write("Snapshot pruned: ${basename(s.path)}");
      }
    }
  }

  static Future<void> _deleteSnapshotFiles(String path) async {
    for (final p in [path, "$path-wal", "$path-shm"]) {
      final f = File(p);
      if (await f.exists()) {
        await f.delete();
      }
    }
  }

  static Future<void> deleteSnapshot(SnapshotInfo snap) async {
    await _deleteSnapshotFiles(snap.path);
    await AppLog.write("Snapshot manually deleted: ${snap.fileName}");
  }

  static Future<void> restore(RunStorage rs, SnapshotInfo snap) async {
    await createSnapshot(rs.db, force: true);

    final dbFilePath = rs.db.path;
    await rs.db.close();

    for (final suffix in ['', '-wal', '-shm']) {
      final target = File("$dbFilePath$suffix");
      if (await target.exists()) {
        await target.delete();
      }
    }

    await File(snap.path).copy(dbFilePath);
    for (final suffix in ['-wal', '-shm']) {
      final side = File("${snap.path}$suffix");
      if (await side.exists()) {
        await side.copy("$dbFilePath$suffix");
      }
    }

    rs.db = await RunStorage.openDb();
    rs.runs = {};
    rs.trackedData = {};
    await rs.loadRuns();

    await AppLog.write("Restored snapshot: ${basename(snap.path)}");
  }
}
