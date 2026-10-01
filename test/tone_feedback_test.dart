import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:run_log/feedback/feedback.dart';
import 'package:run_log/feedback/tones.dart';
import 'package:run_log/stats/run_data.dart';
import 'package:run_log/stats/run_stats.dart';
import 'package:run_log/tabs/running/pace_widget.dart';
import 'package:run_log/tabs/running/tone_feedback.dart';

// Records every playSound call instead of touching real audio hardware,
// and lets a test artificially delay it to simulate a slow native
// round-trip (e.g. FlutterPcmSound taking >1s under real device load).
class RecordingTones extends Tones {
  RecordingTones({required super.sound});

  int playCount = 0;
  Completer<void>? gate;

  @override
  Future<void> playSound(int maxSilence, bool announceChange, RunStats rs) async {
    playCount++;
    if (gate != null) {
      await gate!.future;
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('hasEntry is false when no target speeds are configured', () async {
    final tones = RecordingTones(sound: (await Tones.init()).sound);
    tones.setEntry(SFEntry());

    expect(tones.hasEntry(), false);
  });

  test('hasEntry is true once target speeds are configured', () async {
    final tones = RecordingTones(sound: (await Tones.init()).sound);
    tones.setEntry(SFEntry.startMS(1));

    expect(tones.hasEntry(), true);
  });

  test(
    'No too-slow/too-fast feedback plays when no pace entries are configured',
    () async {
      final tones = RecordingTones(sound: (await Tones.init()).sound);
      tones.setEntry(SFEntry());

      final paceUpdates = StreamController<FeedbackContainer>();
      final feedback = ToneFeedback(
        tones,
        paceUpdates,
        PaceWidget(updateEntries: paceUpdates),
      );
      await feedback.startRunning(4);

      final run = Run.now(1);
      final rs = RunStats([], run);
      var pos = Position(
        longitude: 0,
        latitude: 0,
        timestamp: DateTime.now(),
        accuracy: 1,
        altitude: 0,
        altitudeAccuracy: 0,
        heading: 0,
        headingAccuracy: 0,
        speed: 0,
        speedAccuracy: 0,
      );
      // Get past the GPS-accuracy/start-speed gate and past the first
      // sound interval (15s), same as the re-entrancy test below.
      for (var i = 0; i < 20; i++) {
        pos = Position(
          longitude: pos.longitude + 0.0003,
          latitude: 0,
          timestamp: pos.timestamp.add(const Duration(seconds: 1)),
          accuracy: 1,
          altitude: 0,
          altitudeAccuracy: 0,
          heading: 0,
          headingAccuracy: 0,
          speed: 0,
          speedAccuracy: 0,
        );
        rs.addPosition(pos);
      }

      await feedback.updateRunning(false, rs);

      expect(tones.playCount, 0);
    },
  );

  test(
    'A slow playSound must not be re-entered by an overlapping updateRunning call',
    () async {
      final tones = RecordingTones(sound: (await Tones.init()).sound);
      tones.setEntry(SFEntry.startMS(1));

      final paceUpdates = StreamController<FeedbackContainer>();
      final feedback = ToneFeedback(
        tones,
        paceUpdates,
        PaceWidget(updateEntries: paceUpdates),
      );
      await feedback.startRunning(4);

      final run = Run.now(1);
      final rs = RunStats([], run);
      var pos = Position(
        longitude: 0,
        latitude: 0,
        timestamp: DateTime.now(),
        accuracy: 1,
        altitude: 0,
        altitudeAccuracy: 0,
        heading: 0,
        headingAccuracy: 0,
        speed: 0,
        speedAccuracy: 0,
      );
      // Get past the GPS-accuracy/start-speed gate so runningData is
      // non-empty and durationSec() advances like a real run.
      for (var i = 0; i < 20; i++) {
        pos = Position(
          longitude: pos.longitude + 0.0003,
          latitude: 0,
          timestamp: pos.timestamp.add(const Duration(seconds: 1)),
          accuracy: 1,
          altitude: 0,
          altitudeAccuracy: 0,
          heading: 0,
          headingAccuracy: 0,
          speed: 0,
          speedAccuracy: 0,
        );
        rs.addPosition(pos);
      }

      // Reach the first sound interval (15s) so updateRunning wants to play.
      tones.gate = Completer<void>();
      final first = feedback.updateRunning(false, rs);

      // A second GPS position arrives one second later, while the first
      // playSound() call is still stuck awaiting the native round-trip.
      // With the real scheduling order this fires a second playSound()
      // for the same beep interval.
      final second = feedback.updateRunning(false, rs);

      tones.gate!.complete();
      await first;
      await second;

      expect(tones.playCount, 1);

      // The next beep interval (15s later) must still fire: closing the
      // re-entrancy window must not also swallow legitimate future beeps.
      tones.gate = null;
      for (var i = 0; i < 15; i++) {
        pos = Position(
          longitude: pos.longitude + 0.0003,
          latitude: 0,
          timestamp: pos.timestamp.add(const Duration(seconds: 1)),
          accuracy: 1,
          altitude: 0,
          altitudeAccuracy: 0,
          heading: 0,
          headingAccuracy: 0,
          speed: 0,
          speedAccuracy: 0,
        );
        rs.addPosition(pos);
      }
      await feedback.updateRunning(false, rs);

      expect(tones.playCount, 2);
    },
  );
}
