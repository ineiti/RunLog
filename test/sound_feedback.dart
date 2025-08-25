import 'package:run_log/running/feedback.dart';
import 'package:run_log/running/tones.dart';
import 'package:run_log/stats/conversions.dart';
import 'package:test/test.dart';

void main() {
  expectFloat(double a, double b) {
    expect(a.toStringAsFixed(2), b.toStringAsFixed(2));
  }

  expectMS(double ms, double minKm) {
    if (minKm > 0) {
      expectFloat(ms, toSpeedMS(minKm));
    } else {
      expectFloat(ms, 0);
    }
  }

  test('Create List - 1', () {
    var entry = SFEntry.startMinKm(5);
    entry.addPoint(SpeedPoint.fromMinKm(1000, 10));
    entry.addPoint(SpeedPoint.calc(2000));
    entry.stop(3000);
    entry.calcTotal(20 * 60);
    final speeds = entry.targetSpeeds;
    expect(speeds.length, 4);
    expectMS(speeds[0].speedMS, 5);
    expectMS(speeds[1].speedMS, 10);
    expectMS(speeds[2].speedMS, 5);
    expectMS(speeds[3].speedMS, 20 / 3);
  });

  test('Create List - 2', () {
    var entry = SFEntry.startMinKm(0);
    entry.addPoint(SpeedPoint.fromMinKm(1000, 10));
    entry.addPoint(SpeedPoint.calc(2000));
    entry.stop(3000);
    entry.calcTotal(15 * 60);
    final speeds = entry.targetSpeeds;
    expect(speeds.length, 4);
    expectMS(speeds[0].speedMS, 2.5);
    expectMS(speeds[1].speedMS, 10);
    expectMS(speeds[2].speedMS, 2.5);
    expectMS(speeds[3].speedMS, 5);
  });

  test('Create List - 3', () {
    var entry = SFEntry.startMinKm(0);
    entry.addPoint(SpeedPoint.fromMinKm(500, 10));
    entry.addPoint(SpeedPoint.calc(1000));
    entry.stop(3000);
    entry.calcTotal(30 * 60);
    final speeds = entry.targetSpeeds;
    expect(speeds.length, 4);
    expectMS(speeds[0].speedMS, 10);
    expectMS(speeds[1].speedMS, 10);
    expectMS(speeds[2].speedMS, 10);
    expectMS(speeds[3].speedMS, 10);
  });

  test('Get Duration - 1', () {
    var entry = SFEntry.startMinKm(0);
    entry.addPoint(SpeedPoint.fromMinKm(500, 10));
    entry.addPoint(SpeedPoint.calc(1000));
    entry.stop(3000);
    entry.calcTotal(30 * 60);

    expectFloat(entry.getDurationS(0), 0);
    expectFloat(entry.getDurationS(250), 2.5 * 60);
    expectFloat(entry.getDurationS(500), 5 * 60);
    expectFloat(entry.getDurationS(1000), 10 * 60);
    expectFloat(entry.getDurationS(1500), 15 * 60);
    expectFloat(entry.getDurationS(2000), 20 * 60);
    expectFloat(entry.getDurationS(3000), 30 * 60);
    expectFloat(entry.getDurationS(4000), 40 * 60);
  });

  test('Valle de joux', () {
    final fb24km = SFEntry.startMinKm(6);
    fb24km.addPoint(SpeedPoint.calc(2000));
    fb24km.addPoint(SpeedPoint.fromMinKm(6300, 8));
    fb24km.addPoint(SpeedPoint.fromMinKm(7000, 6));
    fb24km.addPoint(SpeedPoint.fromMinKm(8400, 7));
    fb24km.addPoint(SpeedPoint.fromMinKm(8800, 6));
    fb24km.addPoint(SpeedPoint.fromMinKm(10100, 8));
    fb24km.addPoint(SpeedPoint.calc(10800));
    fb24km.stop(24000);
    fb24km.calcTotal(24 * 6 * 60);
    print(fb24km.targetSpeeds);
  });
}
