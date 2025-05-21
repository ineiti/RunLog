import 'package:flutter/material.dart';
import 'package:run_log/storage.dart';

import 'geotracker.dart';

class Running extends StatefulWidget {
  const Running({super.key, required this.runStorage});

  final RunStorage runStorage; // Add RunStorage property

  @override
  State<Running> createState() => _RunningState();
}

class _RunningState extends State<Running> {
  late GeoTracker tracker;

  @override
  void initState() {
    super.initState();
    tracker = GeoTracker();
  }

  Widget stats(String s) {
    return Text(s, style: Theme.of(context).textTheme.headlineMedium);
  }

  Widget blueButton(String s, VoidCallback click) {
    return TextButton(
      style: TextButton.styleFrom(
        foregroundColor: Colors.white,
        backgroundColor: Colors.lightBlue,
      ),
      onPressed: () {
        setState(() {
          click();
        });
      },
      child: Text(s),
    );
  }

  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return StreamBuilder(
      stream: tracker.stream(),
      builder: (context, snapshot) {
        return Scaffold(
          appBar: AppBar(
            // TRY THIS: Try changing the color here to a specific color (to
            // Colors.amber, perhaps?) and trigger a hot reload to see the AppBar
            // change color while the other colors stay the same.
            backgroundColor: Theme.of(context).colorScheme.inversePrimary,
            // Here we take the value from the MyHomePage object that was created by
            // the App.build method, and use it to set our appbar title.
            title: Text("RunLog"),
          ),
          body: Center(
            // Center is a layout widget. It takes a single child and positions it
            // in the middle of the parent.
            child: Column(
              // TRY THIS: Invoke "debug painting" (choose the "Toggle Debug Paint"
              // action in the IDE, or press "p" in the console), to see the
              // wireframe for each widget.
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Flex(
                  direction: Axis.vertical,
                  children: <Widget>[
                    const Text('Current statistics:'),
                    stats('Curr. Speed: ${tracker.fmtSpeedCurrent()}'),
                    stats('Overall speed: ${tracker.fmtSpeedOverall()}'),

                    stats('Duration: ${tracker.duration().toInt()} s'),
                    stats('Distance: ${tracker.distance().toInt()} m'),
                    Flex(
                      mainAxisAlignment: MainAxisAlignment.center,
                      direction: Axis.horizontal,
                      spacing: 10,
                      children: <Widget>[
                        blueButton("--", () {
                          tracker.pauseSpeedDec();
                        }),
                        Text("PauseSpeed: ${tracker.fmtPauseSpeed()}"),
                        blueButton("++", () {
                          tracker.pauseSpeedInc();
                        }),
                      ],
                    ),
                    Flex(
                      mainAxisAlignment: MainAxisAlignment.center,
                      direction: Axis.horizontal,
                      spacing: 10,
                      children: <Widget>[
                        blueButton("Reset", () {
                          tracker.reset();
                        }),
                        blueButton("Share", () {
                          tracker.share();
                        }),
                      ],
                    ),
                    tracker.liveStats(),
                  ],
                ),
                // )
                // floatingActionButton: FloatingActionButton(
                //   onPressed: _incrementSpeedPause,
                //   tooltip: 'Increment',
                //   child: const Icon(Icons.add),
                // ), // This trailing comma makes auto-formatting nicer for build methods.
              ],
            ),
          ),
        );
      },
    );
  }
}

