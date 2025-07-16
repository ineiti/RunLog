import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class Configuration {
  final bool debug;
  final bool simulateGPS;
  final String altitudeURL;
  final int maxFeedbackIndex;
  static int version = 1;

  static Configuration fromJson(String json) {
    var conf = jsonDecode(json);
    switch ((conf['version'] ?? 0) as int) {
      case 1:
        return Configuration(
          debug: (conf['debug'] ?? false) as bool,
          simulateGPS: (conf['simulateGPS'] ?? false) as bool,
          altitudeURL: (conf['altitudeURL'] ?? "") as String,
          maxFeedbackIndex: (conf['maxFeedbackIndex'] ?? 4) as int,
        );
      default:
        return Configuration(
          debug: false,
          simulateGPS: false,
          altitudeURL: "",
          maxFeedbackIndex: 4,
        );
    }
  }

  Configuration({
    required this.debug,
    required this.simulateGPS,
    required this.altitudeURL,
    required this.maxFeedbackIndex,
  });

  Configuration setDebut(bool debug) {
    return Configuration(
      debug: debug,
      simulateGPS: simulateGPS,
      altitudeURL: altitudeURL,
      maxFeedbackIndex: maxFeedbackIndex,
    );
  }

  Configuration setAltitudeURL(String altitudeURL) {
    return Configuration(
      debug: debug,
      simulateGPS: simulateGPS,
      altitudeURL: altitudeURL,
      maxFeedbackIndex: maxFeedbackIndex,
    );
  }

  Configuration setSimulateGPS(bool simulateGPS) {
    return Configuration(
      debug: debug,
      simulateGPS: simulateGPS,
      altitudeURL: altitudeURL,
      maxFeedbackIndex: maxFeedbackIndex,
    );
  }

  Configuration setMaxFeedbackIndex(int maxFeedbackIndex) {
    return Configuration(
      debug: debug,
      simulateGPS: simulateGPS,
      altitudeURL: altitudeURL,
      maxFeedbackIndex: maxFeedbackIndex,
    );
  }

  String toJson() {
    return jsonEncode({
      'debug': debug,
      'simulateGPS': simulateGPS,
      'altitudeURL': altitudeURL,
      'maxFeedbackIndex': maxFeedbackIndex,
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
