import "dart:math";

import "package:audio_session/audio_session.dart";
import "package:flutter_pcm_sound/flutter_pcm_sound.dart";

import "../stats/conversions.dart" as conversions;

class SoundFeedback {
  List<SFEntry> entries = [];
  final Sound sound;

  static Future<SoundFeedback> init() async {
    return SoundFeedback(sound: await Sound.init());
  }

  SoundFeedback({required this.sound});

  playSound(int idx, double distanceM, double currentDuration) async {
    if (idx > entries.length) {
      return;
    }

    final frequencies = entries[idx].getFrequencies(distanceM, currentDuration);
    await sound.play(frequencies, 0.5, 0.5);
  }
}

class Sound {
  static int sampleRate = 22050;
  static int fade = sampleRate ~/ 8;

  final AudioSession session;
  List<double> frequencies = [];
  int samples = 0;
  double volume = 1;
  int index = 0;

  static Future<Sound> init() async {
    final session = await AudioSession.instance;
    await session.configure(
      AudioSessionConfiguration(
        avAudioSessionCategory: AVAudioSessionCategory.playback,
        avAudioSessionMode: AVAudioSessionMode.defaultMode,
        avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.duckOthers,
        androidAudioAttributes: const AndroidAudioAttributes(
          contentType: AndroidAudioContentType.speech,
          flags: AndroidAudioFlags.none,
          usage: AndroidAudioUsage.voiceCommunication,
        ),
        androidAudioFocusGainType:
            AndroidAudioFocusGainType.gainTransientMayDuck,
        androidWillPauseWhenDucked: false,
      ),
    );
    return Sound(session: session);
  }

  Sound({required this.session});

  play(List<double> freqs, double durationS, double vol) async {
    if (index > 0) {
      // print("Playing already in progress");
      return;
    }
    // print("Start playing");
    frequencies = freqs.map((f) => f / Sound.sampleRate * 2 * pi).toList();
    volume = vol;
    samples = (Sound.sampleRate * durationS).toInt();

    await FlutterPcmSound.release();
    await FlutterPcmSound.setLogLevel(LogLevel.none);
    await FlutterPcmSound.setup(sampleRate: sampleRate, channelCount: 1);
    await FlutterPcmSound.setFeedThreshold(8000);
    FlutterPcmSound.setFeedCallback((rest) => _feed(rest == 0));
    index = 0;
    FlutterPcmSound.start();
  }

  _feed(bool done) async {
    // print("_feed: $done at $index / ${frequencies.length}");
    if (index == 0) {
      await session.setActive(true);
    }
    if (index < frequencies.length) {
      var s = List.generate(
        samples,
        (i) => (((1 << 15) - 1) * volume * sin(i * frequencies[index])).toInt(),
      );

      // Fade each tone in and out exponentially. This takes also care of
      // the clicking sounds between tones because of not matching sine
      // waves.
      var fade = Sound.fade > samples ~/ 2 ? samples ~/ 2 : Sound.fade;
      for (var i = 0; i < fade; i++) {
        s[i] = (s[i] * (pow(2, (i / fade)) - 1)).toInt();
      }
      for (var i = 1; i <= fade; i++) {
        s[samples - i] = (s[samples - i] * (pow(2, (i / fade)) - 1)).toInt();
      }
      // print("feeding $index at ${DateTime.timestamp()}");
      await FlutterPcmSound.feed((PcmArrayInt16.fromList(s)));
      index += 1;
    } else if (done) {
      // print("done ${DateTime.timestamp()}");
      await session.setActive(false);
      index = 0;
    }
  }
}

class SFEntry {
  List<SpeedPoint> targetSpeeds = [];
  double frequencyS = 30;

  static SFEntry startMinKm(double start) {
    var sf = SFEntry();
    sf.addPoint(SpeedPoint.fromMinKm(0, start));
    return sf;
  }

  static SFEntry startMS(double start) {
    var sf = SFEntry();
    sf.addPoint(SpeedPoint(distanceM: 0, speedMS: start));
    return sf;
  }

  static SFEntry start() {
    var sf = SFEntry();
    sf.addPoint(SpeedPoint(distanceM: 0, speedMS: 0));
    return sf;
  }

  stop(double distanceM) {
    addPoint(SpeedPoint(distanceM: distanceM, speedMS: 0));
  }

  addPoint(SpeedPoint sp) {
    targetSpeeds.add(sp);
  }

  calcTotal(double totalDurationS) {
    if (targetSpeeds.length < 2) {
      return;
    }
    targetSpeeds.sort((a, b) => a.distanceM.compareTo(b.distanceM));
    double restDistanceM = targetSpeeds.last.distanceM;
    var restDurationS = totalDurationS;
    for (int i = 0; i < targetSpeeds.length - 1; i++) {
      SpeedPoint start = targetSpeeds[i];
      if (start.speedMS > 0) {
        SpeedPoint stop = targetSpeeds[i + 1];
        double dist = stop.distanceM - start.distanceM;
        restDurationS -= dist / start.speedMS;
        restDistanceM -= dist;
      }
    }

    final restSpeed = restDistanceM / restDurationS;
    for (int i = 0; i < targetSpeeds.length - 1; i++) {
      SpeedPoint start = targetSpeeds[i];
      if (start.speedMS == 0) {
        start.speedMS = restSpeed;
      }
    }
    targetSpeeds.last.speedMS = targetSpeeds.last.distanceM / totalDurationS;
  }

  double getDurationS(double distanceM) {
    if (targetSpeeds.isEmpty) {
      return 0;
    }
    if (targetSpeeds.length == 1) {
      return distanceM / targetSpeeds.first.speedMS;
    }
    double duration = 0;
    for (int i = 0; i < targetSpeeds.length - 1; i++) {
      final now = targetSpeeds[i];
      final after = targetSpeeds[i + 1].distanceM;
      if (after >= distanceM) {
        return duration + (distanceM - now.distanceM) / now.speedMS;
      } else {
        duration += (after - now.distanceM) / now.speedMS;
      }
    }
    return duration +
        (distanceM - targetSpeeds.last.distanceM) / targetSpeeds.last.speedMS;
  }

  List<double> getFrequencies(double distanceM, double currentDuration) {
    var diffDuration =
        ((currentDuration - getDurationS(distanceM)) / 5).toInt();
    final List<double> frequencies = [440];
    while (diffDuration != 0) {
      frequencies.add(frequencies.last * pow(2, diffDuration.sign / 12));
      diffDuration -= diffDuration.sign;
    }
    return frequencies;
  }
}

class SpeedPoint {
  double distanceM;
  double speedMS;

  SpeedPoint({required this.distanceM, required this.speedMS});

  static SpeedPoint fromMinKm(double distanceM, double speedMinKm) {
    return SpeedPoint(
      distanceM: distanceM,
      speedMS: conversions.toSpeedMS(speedMinKm),
    );
  }

  static SpeedPoint calc(double distanceM) {
    return SpeedPoint(distanceM: distanceM, speedMS: 0);
  }

  @override
  String toString() {
    return "($distanceM, ${conversions.toPaceMinKm(speedMS).toStringAsFixed(3)})";
  }
}
