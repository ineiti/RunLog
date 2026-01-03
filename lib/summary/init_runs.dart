import 'package:run_log/stats/run_data.dart';
import 'package:run_log/summary/preview_map.dart';
import 'package:run_log/summary/summary.dart';

import '../configuration.dart';
import '../storage.dart';

class InitRuns {
  final RunStorage runStorage;
  final ConfigurationStorage configurationStorage;

  InitRuns(this.runStorage, this.configurationStorage);

  Future<void> updateAll() async {
    var changed = false;
    for (final run in runStorage.runs.values) {
      changed |= await summarize(run.id);
    }
    if (changed) {
      final others = Map.fromEntries(
        runStorage.runs.values.map(
          (run) => MapEntry(run.id, run.summary!.trace),
        ),
      );
      for (final run in runStorage.runs.values) {
        run.summary!.similar =
            run.summary!
                .closest(others)
                .where((run) => run.$2 > 0)
                .map((run) => run.$1)
                .toList();
      }
    }
  }

  Future<bool> summarize(int id) async {
    final run = runStorage.runs[id];
    if (run == null) {
      return false;
    }
    if (run.summary == null ||
        run.summary!.trace.isEmpty ||
        run.summary!.mapIcon == null) {
      final trace = await runStorage.loadTrackedData(run.id);
      final summary = SummaryContainer.fromData(trace);
      summary.mapIcon = await MapPreviewGenerator.generateMapPreview(
        trace: trace.toLatLng(),
        width: 64,
        height: 64,
      );
      run.summary = summary;
      await runStorage.updateRun(run);
      return true;
    }
    return false;
  }
}
