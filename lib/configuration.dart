import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class Configuration {
  final bool debug;
  final bool simulateGPS;
  final String altitudeURL;
  final int maxFeedbackSoundWait;
  final double minFeedbackPace;
  final double maxFeedbackPace;
  static int version = 1;

  static Configuration fromJson(String json) {
    var conf = jsonDecode(json);
    switch ((conf['version'] ?? 0) as int) {
      case 1:
        return Configuration(
          debug: (conf['debug'] ?? false) as bool,
          simulateGPS: (conf['simulateGPS'] ?? false) as bool,
          altitudeURL: (conf['altitudeURL'] ?? "") as String,
          maxFeedbackSoundWait: (conf['maxFeedbackSoundWait'] ?? 4) as int,
          minFeedbackPace: (conf['minFeedbackPace'] ?? 4.0) as double,
          maxFeedbackPace: (conf['maxFeedbackPace'] ?? 8.0) as double,
        );
      default:
        return Configuration(
          debug: false,
          simulateGPS: false,
          altitudeURL: "",
          maxFeedbackSoundWait: 4,
          minFeedbackPace: 4,
          maxFeedbackPace: 8,
        );
    }
  }

  Configuration({
    required this.debug,
    required this.simulateGPS,
    required this.altitudeURL,
    required this.maxFeedbackSoundWait,
    required this.minFeedbackPace,
    required this.maxFeedbackPace,
  });

  Configuration setDebug(bool debug) {
    return Configuration(
      debug: debug,
      simulateGPS: simulateGPS,
      altitudeURL: altitudeURL,
      maxFeedbackSoundWait: maxFeedbackSoundWait,
      minFeedbackPace: minFeedbackPace,
      maxFeedbackPace: maxFeedbackPace,
    );
  }

  Configuration setAltitudeURL(String altitudeURL) {
    return Configuration(
      debug: debug,
      simulateGPS: simulateGPS,
      altitudeURL: altitudeURL,
      maxFeedbackSoundWait: maxFeedbackSoundWait,
      minFeedbackPace: minFeedbackPace,
      maxFeedbackPace: maxFeedbackPace,
    );
  }

  Configuration setSimulateGPS(bool simulateGPS) {
    return Configuration(
      debug: debug,
      simulateGPS: simulateGPS,
      altitudeURL: altitudeURL,
      maxFeedbackSoundWait: maxFeedbackSoundWait,
      minFeedbackPace: minFeedbackPace,
      maxFeedbackPace: maxFeedbackPace,
    );
  }

  Configuration setMaxFeedbackIndex(int maxFeedbackSoundWait) {
    return Configuration(
      debug: debug,
      simulateGPS: simulateGPS,
      altitudeURL: altitudeURL,
      maxFeedbackSoundWait: maxFeedbackSoundWait,
      minFeedbackPace: minFeedbackPace,
      maxFeedbackPace: maxFeedbackPace,
    );
  }

  Configuration setMinFeedbackPace(double minFeedbackPace) {
    return Configuration(
      debug: debug,
      simulateGPS: simulateGPS,
      altitudeURL: altitudeURL,
      maxFeedbackSoundWait: maxFeedbackSoundWait,
      minFeedbackPace: minFeedbackPace,
      maxFeedbackPace: maxFeedbackPace,
    );
  }

  Configuration setMaxFeedbackPace(double maxFeedbackPace) {
    return Configuration(
      debug: debug,
      simulateGPS: simulateGPS,
      altitudeURL: altitudeURL,
      maxFeedbackSoundWait: maxFeedbackSoundWait,
      minFeedbackPace: minFeedbackPace,
      maxFeedbackPace: maxFeedbackPace,
    );
  }

  String toJson() {
    return jsonEncode({
      'debug': debug,
      'simulateGPS': simulateGPS,
      'altitudeURL': altitudeURL,
      'maxFeedbackSoundWait': maxFeedbackSoundWait,
      'minFeedbackPace': minFeedbackPace,
      'maxFeedbackPace': maxFeedbackPace,
      'version': version,
    });
  }
}

class ConfigurationStorage {
  Configuration config;
  final SharedPreferences prefs;

  static Future<ConfigurationStorage> loadConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final config = Configuration.fromJson(prefs.getString("config") ?? "{}");
    return ConfigurationStorage(config: config, prefs: prefs);
  }

  ConfigurationStorage({required this.config, required this.prefs});

  updateConfig(Configuration newConfig) async {
    await prefs.setString("config", newConfig.toJson());
    config = newConfig;
  }
}
