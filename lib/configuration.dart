import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class Configuration {
  final bool debug;
  final bool simulateGPS;
  final String altitudeURL;
  final int maxFeedbackSoundWait;
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
        );
      default:
        return Configuration(
          debug: false,
          simulateGPS: false,
          altitudeURL: "",
          maxFeedbackSoundWait: 4,
        );
    }
  }

  Configuration({
    required this.debug,
    required this.simulateGPS,
    required this.altitudeURL,
    required this.maxFeedbackSoundWait,
  });

  Configuration setDebut(bool debug) {
    return Configuration(
      debug: debug,
      simulateGPS: simulateGPS,
      altitudeURL: altitudeURL,
      maxFeedbackSoundWait: maxFeedbackSoundWait,
    );
  }

  Configuration setAltitudeURL(String altitudeURL) {
    return Configuration(
      debug: debug,
      simulateGPS: simulateGPS,
      altitudeURL: altitudeURL,
      maxFeedbackSoundWait: maxFeedbackSoundWait,
    );
  }

  Configuration setSimulateGPS(bool simulateGPS) {
    return Configuration(
      debug: debug,
      simulateGPS: simulateGPS,
      altitudeURL: altitudeURL,
      maxFeedbackSoundWait: maxFeedbackSoundWait,
    );
  }

  Configuration setMaxFeedbackIndex(int maxFeedbackSoundWait) {
    return Configuration(
      debug: debug,
      simulateGPS: simulateGPS,
      altitudeURL: altitudeURL,
      maxFeedbackSoundWait: maxFeedbackSoundWait,
    );
  }

  String toJson() {
    return jsonEncode({
      'debug': debug,
      'simulateGPS': simulateGPS,
      'altitudeURL': altitudeURL,
      'maxFeedbackSoundWait': maxFeedbackSoundWait,
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
