import 'package:flutter/material.dart';

import '../configuration.dart';

class Settings extends StatefulWidget {
  const Settings({super.key, required this.configurationStorage});

  final ConfigurationStorage configurationStorage; // Configuration

  @override
  State<Settings> createState() => _SettingsState();
}

class _SettingsState extends State<Settings> {
  final TextEditingController _altitudeURL = TextEditingController();

  @override
  void initState() {
    super.initState();
    _altitudeURL.text = widget.configurationStorage.config.altitudeURL;
  }

  @override
  Widget build(BuildContext context) {
    // print("Items are: ${runs.length} - ${widget.runStorage.runs}");
    // print(widget.runStorage);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text("Settings"),
      ),
      body: Column(
        children: <Widget>[
          CheckboxListTile(
            title: Text("Debug mode"),
            value: widget.configurationStorage.config.debug,
            onChanged: (bool? value) async {
              if (value != null) {
                await widget.configurationStorage.updateConfig(
                  widget.configurationStorage.config.setDebut(value),
                );
                setState(() {});
              }
            },
          ),
          CheckboxListTile(
            title: Text("Simulate GPS"),
            value: widget.configurationStorage.config.simulateGPS,
            onChanged: (bool? value) async {
              if (value != null) {
                await widget.configurationStorage.updateConfig(
                  widget.configurationStorage.config.setSimulateGPS(value),
                );
                setState(() {});
              }
            },
          ),
          TextField(
            controller: _altitudeURL,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              labelText: 'Altitude URL',
            ),
            onChanged: (String s) async {
              await widget.configurationStorage.updateConfig(
                widget.configurationStorage.config.setAltitudeURL(s),
              );
            },
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            spacing: 10,
            children: [
              Text(
                "  ${widget.configurationStorage.config.maxFeedbackIndex} x",
              ),
              Flexible(
                child: Slider(
                  value:
                      widget.configurationStorage.config.maxFeedbackIndex
                          .toDouble(),
                  onChanged: (double value) async {
                    await widget.configurationStorage.updateConfig(
                      widget.configurationStorage.config.setMaxFeedbackIndex(
                        value.toInt(),
                      ),
                    );
                    setState(() {});
                  },
                  min: 1,
                  divisions: 10,
                  max: 10,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
