import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class Configuration {
  final bool debug;
  final String altitudeURL;
  static int version = 1;

  static Configuration fromJson(String json) {
    var conf = jsonDecode(json);
    switch ((conf['version'] ?? 0) as int) {
      case 1:
        return Configuration(
          debug: (conf['debug'] ?? false) as bool,
          altitudeURL: (conf['altitudeURL'] ?? "") as String,
        );
      default:
        return Configuration(debug: false, altitudeURL: "");
    }
  }

  Configuration({required this.debug, required this.altitudeURL});

  Configuration setDebut(bool debug) {
    return Configuration(debug: debug, altitudeURL: altitudeURL);
  }

  Configuration setAltitudeURL(String altitudeURL) {
    return Configuration(debug: debug, altitudeURL: altitudeURL);
  }

  String toJson() {
    return jsonEncode({
      'debug': debug,
      'altitudeURL': altitudeURL,
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
