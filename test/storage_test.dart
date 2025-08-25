import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:run_log/storage.dart';

void main() {
  test('Exporting and re-importing all', () async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    RunStorage.dbName = "test_db.db";
    var rs = await RunStorage.init();
    await rs.cleanDB();
    await DebugStorage.dbPrefill(
      rs,
      Duration(hours: 5),
      10,
      [4, .2, .1, .4, .1, .2],
      [2000, 20, 10, 20, 10],
    );
    await DebugStorage.dbPrefill(
      rs,
      Duration(hours: 2),
      5,
      [4, .2, .1, .4, .1, .2],
      [2000, 20, 10, 20, 10],
    );

    final dump = await rs.exportAll();

    RunStorage.dbName = "test_db_2.db";
    var rs2 = await RunStorage.init();
    await rs2.cleanDB();
    await rs2.importAll(dump);

    expect(2, rs2.runs.length);
    expect(10, rs2.trackedData[1]?.length);
    expect(5, rs2.trackedData[2]?.length);
    expect(rs.runs, rs2.runs);
  });
}
