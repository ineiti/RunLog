import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:run_log/summary/preview_map.dart';

class OpenStreetMapWidget extends StatefulWidget {
  final List<LatLng> points;
  final LatLng? initialCenter;
  final Color polylineColor;
  final double polylineWidth;
  final Color markerColor;
  final double markerSize;

  const OpenStreetMapWidget({
    super.key,
    required this.points,
    this.initialCenter,
    this.polylineColor = Colors.blue,
    this.polylineWidth = 5.0,
    this.markerColor = Colors.red,
    this.markerSize = 40.0,
  });

  @override
  State<OpenStreetMapWidget> createState() => _OpenStreetMapWidgetState();
}

class _OpenStreetMapWidgetState extends State<OpenStreetMapWidget> {
  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCameraFit: CameraFit.bounds(
          bounds: LatLngBounds.fromPoints(widget.points).zoomOut(1.2),
        ),
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all, // Enable all interactions
        ),
        onTap: (_, __) {}, // Handle map taps if needed
      ),
      children: [
        // OpenStreetMap tile layer
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'ch.ineiti.run_log',
        ),
        RichAttributionWidget(
          attributions: [TextSourceAttribution('OpenStreetMap contributors')],
        ),

        // Polyline layer
        if (widget.points.length >= 2)
          PolylineLayer(
            polylines: [
              Polyline(
                points: widget.points,
                color: widget.polylineColor,
                strokeWidth: widget.polylineWidth,
              ),
            ],
          ),
      ],
    );
  }

  // Public methods you can call from parent widget
  void zoomIn() {
    _mapController.move(
      _mapController.camera.center,
      _mapController.camera.zoom + 1,
    );
  }

  void zoomOut() {
    _mapController.move(
      _mapController.camera.center,
      _mapController.camera.zoom - 1,
    );
  }

  void centerOnPoints() {
    if (widget.points.isEmpty) return;

    final bounds = LatLngBounds.fromPoints(widget.points);
    _mapController.fitCamera(
      CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(50.0)),
    );
  }
}
