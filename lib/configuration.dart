import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

enum _Fields {
  config,
  version,
  debug,
  simulateGPS,
  altitudeURL,
  maxFeedbackSilence,
  minFeedbackPace,
  maxFeedbackPace,
  announceTargetChange,
}

class Configuration {
  final bool debug;
  final bool simulateGPS;
  final String altitudeURL;
  final int maxFeedbackSilence;
  final double minFeedbackPace;
  final double maxFeedbackPace;
  final bool announceTargetChange;
  static int version = 1;

  static Configuration fromJson(String json) {
    dynamic conf = jsonDecode(json);
    switch ((conf[_Fields.version.name] ?? 0) as int) {
      case 1:
        return Configuration(
          debug: (conf[_Fields.debug.name] ?? false) as bool,
          simulateGPS: (conf[_Fields.simulateGPS.name] ?? false) as bool,
          altitudeURL: (conf[_Fields.altitudeURL.name] ?? "") as String,
          maxFeedbackSilence:
              (conf[_Fields.maxFeedbackSilence.name] ?? 4) as int,
          minFeedbackPace:
              (conf[_Fields.minFeedbackPace.name] ?? 4.0) as double,
          maxFeedbackPace:
              (conf[_Fields.maxFeedbackPace.name] ?? 8.0) as double,
          announceTargetChange:
              (conf[_Fields.announceTargetChange.name] ?? false) as bool,
        );
      default:
        return Configuration(
          debug: false,
          simulateGPS: false,
          altitudeURL: "",
          maxFeedbackSilence: 4,
          minFeedbackPace: 4,
          maxFeedbackPace: 8,
          announceTargetChange: false,
        );
    }
  }

  Configuration({
    required this.debug,
    required this.simulateGPS,
    required this.altitudeURL,
    required this.maxFeedbackSilence,
    required this.minFeedbackPace,
    required this.maxFeedbackPace,
    required this.announceTargetChange,
  });

  Configuration setDebug(bool debug) {
    return Configuration(
      debug: debug,
      simulateGPS: simulateGPS,
      altitudeURL: altitudeURL,
      maxFeedbackSilence: maxFeedbackSilence,
      minFeedbackPace: minFeedbackPace,
      maxFeedbackPace: maxFeedbackPace,
      announceTargetChange: announceTargetChange,
    );
  }

  Configuration setAltitudeURL(String altitudeURL) {
    return Configuration(
      debug: debug,
      simulateGPS: simulateGPS,
      altitudeURL: altitudeURL,
      maxFeedbackSilence: maxFeedbackSilence,
      minFeedbackPace: minFeedbackPace,
      maxFeedbackPace: maxFeedbackPace,
      announceTargetChange: announceTargetChange,
    );
  }

  Configuration setSimulateGPS(bool simulateGPS) {
    return Configuration(
      debug: debug,
      simulateGPS: simulateGPS,
      altitudeURL: altitudeURL,
      maxFeedbackSilence: maxFeedbackSilence,
      minFeedbackPace: minFeedbackPace,
      maxFeedbackPace: maxFeedbackPace,
      announceTargetChange: announceTargetChange,
    );
  }

  Configuration setMaxFeedbackIndex(int maxFeedbackSoundWait) {
    return Configuration(
      debug: debug,
      simulateGPS: simulateGPS,
      altitudeURL: altitudeURL,
      maxFeedbackSilence: maxFeedbackSoundWait,
      minFeedbackPace: minFeedbackPace,
      maxFeedbackPace: maxFeedbackPace,
      announceTargetChange: announceTargetChange,
    );
  }

  Configuration setMinFeedbackPace(double minFeedbackPace) {
    return Configuration(
      debug: debug,
      simulateGPS: simulateGPS,
      altitudeURL: altitudeURL,
      maxFeedbackSilence: maxFeedbackSilence,
      minFeedbackPace: minFeedbackPace,
      maxFeedbackPace: maxFeedbackPace,
      announceTargetChange: announceTargetChange,
    );
  }

  Configuration setMaxFeedbackPace(double maxFeedbackPace) {
    return Configuration(
      debug: debug,
      simulateGPS: simulateGPS,
      altitudeURL: altitudeURL,
      maxFeedbackSilence: maxFeedbackSilence,
      minFeedbackPace: minFeedbackPace,
      maxFeedbackPace: maxFeedbackPace,
      announceTargetChange: announceTargetChange,
    );
  }

  Configuration setAnnounceTargetChange(bool announceTargetChange) {
    return Configuration(
      debug: debug,
      simulateGPS: simulateGPS,
      altitudeURL: altitudeURL,
      maxFeedbackSilence: maxFeedbackSilence,
      minFeedbackPace: minFeedbackPace,
      maxFeedbackPace: maxFeedbackPace,
      announceTargetChange: announceTargetChange,
    );
  }

  String toJson() {
    return jsonEncode(<String, Object>{
      _Fields.debug.name: debug,
      _Fields.simulateGPS.name: simulateGPS,
      _Fields.altitudeURL.name: altitudeURL,
      _Fields.maxFeedbackSilence.name: maxFeedbackSilence,
      _Fields.minFeedbackPace.name: minFeedbackPace,
      _Fields.maxFeedbackPace.name: maxFeedbackPace,
      _Fields.announceTargetChange.name: announceTargetChange,
      _Fields.version.name: version,
    });
  }
}

class ConfigurationStorage {
  Configuration config;
  final SharedPreferences prefs;

  static Future<ConfigurationStorage> loadConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final config = Configuration.fromJson(
      prefs.getString(_Fields.config.name) ?? "{}",
    );
    return ConfigurationStorage(config: config, prefs: prefs);
  }

  ConfigurationStorage({required this.config, required this.prefs});

  Future<void> updateConfig(Configuration newConfig) async {
    await prefs.setString(_Fields.config.name, newConfig.toJson());
    config = newConfig;
  }
}
