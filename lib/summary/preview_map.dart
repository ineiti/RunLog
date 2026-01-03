import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class MapPreviewGenerator {
  static TileLayer tileLayer = TileLayer(
    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
    userAgentPackageName: 'ch.ineiti.run_log',
  );
  static const int _tileSize = 256;

  /// Generates a map preview image from a list of coordinates
  ///
  /// [trace] - List of LatLng points for the running trace
  /// [width] - Output image width in pixels
  /// [height] - Output image height in pixels
  /// [lineColor] - Color for the trace line
  /// [lineWidth] - Width of the trace line
  /// [showStartEnd] - Whether to show markers for start and end points
  ///
  /// Returns: Uint8List suitable for Image.memory()
  static Future<Uint8List> generateMapPreview({
    required List<LatLng> trace,
    required int width,
    required int height,
    Color lineColor = Colors.blue,
    double lineWidth = 3.0,
    bool showStartEnd = true,
  }) async {
    if (trace.isEmpty) {
      throw ArgumentError('Trace list cannot be empty');
    }

    // Calculate bounding box
    final boundsRaw = LatLngBounds.fromPoints(trace);
    final (bounds, zoom) = boundsRaw.ratioZoom(_tileSize, width, height);
    final center = bounds.center;

    // Calculate tile coordinates
    final centerTileX = center.tileX(zoom);
    final centerTileY = center.tileY(zoom);

    // Create picture recorder
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(
      recorder,
      Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    );

    // Draw background
    _drawBackground(canvas, width, height);

    // Fetch and draw tiles
    await _drawTiles(
      canvas: canvas,
      centerTileX: centerTileX,
      centerTileY: centerTileY,
      zoom: zoom,
      width: width,
      height: height,
    );

    // Draw the trace
    _drawTrace(
      canvas: canvas,
      trace: trace,
      bounds: bounds,
      width: width,
      height: height,
      lineColor: lineColor,
      lineWidth: lineWidth,
    );

    // Draw start and end markers if requested
    if (showStartEnd && trace.length >= 2) {
      _drawStartEndMarkers(
        canvas: canvas,
        trace: trace,
        bounds: bounds,
        width: width,
        height: height,
      );
    }

    // Convert to image
    final picture = recorder.endRecording();
    final image = await picture.toImage(width, height);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

    return byteData!.buffer.asUint8List();
  }

  static void _drawBackground(Canvas canvas, int width, int height) {
    final paint =
        Paint()
          ..color = const Color(0xFFEEEEEE)
          ..style = PaintingStyle.fill;

    canvas.drawRect(
      Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
      paint,
    );
  }

  static Future<void> _drawTiles({
    required Canvas canvas,
    required double centerTileX,
    required double centerTileY,
    required int zoom,
    required int width,
    required int height,
  }) async {
    final tilePaint =
        Paint()
          ..filterQuality = FilterQuality.medium
          ..isAntiAlias = false;

    final widthTiles = (width / _tileSize).ceil();
    final heightTiles = (height / _tileSize).ceil();
    for (int dx = -widthTiles; dx <= widthTiles; dx++) {
      for (int dy = -heightTiles; dy <= heightTiles; dy++) {
        final tileX = (centerTileX + dx).floor();
        final offsetX = ((tileX - centerTileX) * _tileSize + width / 2);
        if (offsetX <= -_tileSize || offsetX >= width) {
          continue;
        }
        final tileY = (centerTileY + dy).floor();
        final offsetY = ((tileY - centerTileY) * _tileSize + height / 2);
        if (offsetY <= -_tileSize || offsetY >= height) {
          continue;
        }

        try {
          final imageStream = tileLayer.tileProvider
              .getImageWithCancelLoadingSupport(
                TileCoordinates(tileX, tileY, zoom),
                tileLayer,
                Future.delayed(Duration(seconds: 1)),
              )
              .resolve(ImageConfiguration.empty);
          // Create a completer to await the image
          final completer = Completer<ui.Image>();
          late ImageStreamListener listener;
          listener = ImageStreamListener(
            (ImageInfo info, bool syncCall) {
              imageStream.removeListener(listener); // Clean up immediately
              completer.complete(info.image);
            },
            onError: (dynamic exception, StackTrace? stackTrace) {
              print("Got an error: $exception");
              imageStream.removeListener(listener); // Clean up on error
              completer.completeError(exception, stackTrace);
            },
          );

          imageStream.addListener(listener);

          // Await the completer's future to get the ui.Image
          final tileImage = await completer.future;
          if (tileImage.height == 1) {
            print("Very small tileImage");
          }

          // Calculate position for this tile
          canvas.drawImage(tileImage, Offset(offsetX, offsetY), tilePaint);
        } catch (e) {
          // Tile might not exist or failed to load, skip it
          print("Got error: $e");
          continue;
        }
      }
    }
  }

  static void _drawTrace({
    required Canvas canvas,
    required List<LatLng> trace,
    required LatLngBounds bounds,
    required int width,
    required int height,
    required Color lineColor,
    required double lineWidth,
  }) {
    if (trace.length < 2) return;

    final paint =
        Paint()
          ..color = lineColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = lineWidth
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..isAntiAlias = true;

    final path = ui.Path();

    // Convert first point to screen coordinates
    final firstPoint = trace.first.toOffset(bounds, width, height);
    path.moveTo(firstPoint.dx, firstPoint.dy);

    // Add remaining points
    for (int i = 1; i < trace.length; i++) {
      final point = trace[i].toOffset(bounds, width, height);
      path.lineTo(point.dx, point.dy);
    }

    canvas.drawPath(path, paint);
  }

  static void _drawStartEndMarkers({
    required Canvas canvas,
    required List<LatLng> trace,
    required LatLngBounds bounds,
    required int width,
    required int height,
  }) {
    final startPoint = trace.first.toOffset(bounds, width, height);
    final endPoint = trace.last.toOffset(bounds, width, height);

    // Draw start marker (green)
    final startPaint =
        Paint()
          ..color = Colors.green
          ..style = PaintingStyle.fill;

    final inner = max(2, 6 * width / 256).toDouble();
    final outer = max(3, 8 * width / 256).toDouble();
    canvas.drawCircle(startPoint, inner, startPaint);
    canvas.drawCircle(
      startPoint,
      outer,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = outer - inner,
    );

    // Draw end marker (red)
    final endPaint =
        Paint()
          ..color = Colors.red
          ..style = PaintingStyle.fill;

    canvas.drawCircle(endPoint, inner, endPaint);
    canvas.drawCircle(
      endPoint,
      outer,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = outer - inner,
    );
  }
}

extension OSM on LatLng {
  double tileX(int zoom) {
    return ((longitude + 180) / 360 * pow(2, zoom));
  }

  double tileY(int zoom) {
    return ((1 - log(tan(latitudeInRad) + 1 / cos(latitudeInRad)) / pi) /
        2 *
        pow(2, zoom));
  }

  Offset toOffset(LatLngBounds bounds, int width, int height) {
    final normalizedX = (longitude - bounds.west) / bounds.longitudeWidth;
    final normalizedY =
        1 - ((latitude - bounds.south) / (bounds.latitudeHeight));

    return Offset(normalizedX * width, normalizedY * height);
  }
}

extension Ratio on LatLngBounds {
  double get latitudeHeight => north - south;

  // This calculates the correct bounds to fit the trace into
  // a rectangle, so the rectangle has the ration width/height.
  (LatLngBounds, int) ratioZoom(int tileSize, int width, int height) {
    final heightLL = Vincenty().distance(southWest, northWest);
    final widthLL = Vincenty().distance(southWest, southEast);

    // Calculate expansion factors
    final llAspect = widthLL / heightLL;
    final targetAspect = width / height;
    double newWidth, newHeight;
    if (llAspect > targetAspect) {
      newHeight = heightLL * llAspect / targetAspect;
      newWidth = widthLL;
    } else {
      newHeight = heightLL;
      newWidth = widthLL * targetAspect / llAspect;
    }

    // Align with integer zoom factor by calculating the height of the
    // closest zoom and adjusting the new height and width.
    final newWidthLL = (east - west) * newWidth / widthLL;
    final zoomFract = log(360 * width / (newWidthLL * tileSize)) / ln2;
    final zoom = zoomFract.floor();
    final zoomOut = pow(2, zoomFract - zoom);
    newHeight *= zoomOut;
    newWidth *= zoomOut;

    // Expand from center using cardinal directions, then extend
    // the current bound.
    // This supposes that the bound will only increase in both width
    // and height.
    final newSw_ = Vincenty().offset(center, newHeight / 2, 180); // South
    final newNe_ = Vincenty().offset(center, newHeight / 2, 0); // North
    extend(Vincenty().offset(newSw_, newWidth / 2, 270)); // West
    extend(Vincenty().offset(newNe_, newWidth / 2, 90)); // East

    return (LatLngBounds(southWest, northEast), zoom);
  }

  LatLngBounds zoomOut(double zo) {
    final c = center;
    final width = longitudeWidth * zo;
    final height = latitudeHeight * zo;
    return LatLngBounds(
      LatLng(c.latitude + height / 2, c.longitude - width / 2),
      LatLng(c.latitude - height / 2, c.longitude + width / 2),
    );
  }
}
