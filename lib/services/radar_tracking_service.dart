import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;

/// Result of image-based tracking of the nearest precipitation area.
///
/// IMPORTANT: this is based on real RainViewer radar frames, but the motion
/// vector is estimated from raster images. It is therefore a nowcast estimate,
/// not an official meteorological warning or a Doppler velocity product.
class RadarTrackingResult {
  final DateTime generatedAt;
  final bool radarAvailable;
  final bool precipitationDetected;
  final bool approaching;
  final bool pathIntersectsUser;

  /// Distance from the user to the nearest detected precipitation edge.
  final double? distanceKm;

  /// Estimated motion of the tracked precipitation area.
  final double? speedKmh;
  final double? movementBearingDeg;

  /// Direction FROM which the nearest precipitation lies, measured clockwise
  /// from geographic north.
  final double? precipitationBearingDeg;

  /// ETA to the user's position. Null when the path is not sufficiently
  /// reliable or does not intersect the user.
  final int? etaMinutes;

  /// 0..1. Keep UI wording honest when this is low.
  final double confidence;

  /// Estimated closest pass of the tracked centroid/path.
  final double? closestApproachKm;

  /// Approximate radius of the selected precipitation component.
  final double? componentRadiusKm;

  final int framesUsed;
  final String source;
  final String status;

  const RadarTrackingResult({
    required this.generatedAt,
    required this.radarAvailable,
    required this.precipitationDetected,
    required this.approaching,
    required this.pathIntersectsUser,
    required this.distanceKm,
    required this.speedKmh,
    required this.movementBearingDeg,
    required this.precipitationBearingDeg,
    required this.etaMinutes,
    required this.confidence,
    required this.closestApproachKm,
    required this.componentRadiusKm,
    required this.framesUsed,
    required this.source,
    required this.status,
  });

  factory RadarTrackingResult.unavailable(String status) {
    return RadarTrackingResult(
      generatedAt: DateTime.now(),
      radarAvailable: false,
      precipitationDetected: false,
      approaching: false,
      pathIntersectsUser: false,
      distanceKm: null,
      speedKmh: null,
      movementBearingDeg: null,
      precipitationBearingDeg: null,
      etaMinutes: null,
      confidence: 0,
      closestApproachKm: null,
      componentRadiusKm: null,
      framesUsed: 0,
      source: 'RainViewer',
      status: status,
    );
  }

  String get confidenceText {
    if (confidence >= 0.75) return 'vysoká';
    if (confidence >= 0.50) return 'stredná';
    if (confidence > 0) return 'nízka';
    return 'nedostupná';
  }
}

class RadarTrackingService {
  static const String _mapsUrl =
      'https://api.rainviewer.com/public/weather-maps.json';

  // RainViewer free Weather Maps API is limited to zoom <= 7.
  static const int _zoom = 7;
  static const int _tileSize = 256;
  static const int _colorScheme = 2; // Universal Blue

  // Four 10-minute frames give a ~30-minute observed motion baseline.
  static const int _wantedFrames = 4;

  // Ignore tiny isolated compression/noise specks.
  static const int _minimumComponentPixels = 4;

  final http.Client _client;

  RadarTrackingService({http.Client? client})
      : _client = client ?? http.Client();

  Future<RadarTrackingResult> track({
    required double latitude,
    required double longitude,
  }) async {
    try {
      final timelineResponse = await _client
          .get(Uri.parse(_mapsUrl))
          .timeout(const Duration(seconds: 12));

      if (timelineResponse.statusCode != 200) {
        return RadarTrackingResult.unavailable(
          'Radar timeline HTTP ${timelineResponse.statusCode}',
        );
      }

      final root = jsonDecode(timelineResponse.body);
      if (root is! Map<String, dynamic>) {
        return RadarTrackingResult.unavailable(
          'Radar timeline má neplatný formát.',
        );
      }

      final host = root['host']?.toString();
      final radar = root['radar'];
      final past = radar is Map<String, dynamic> ? radar['past'] : null;

      if (host == null || past is! List || past.isEmpty) {
        return RadarTrackingResult.unavailable(
          'RainViewer momentálne nevrátil radarové snímky.',
        );
      }

      final rawFrames = past
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .where((e) => e['time'] is num && e['path'] != null)
          .toList()
        ..sort((a, b) =>
            (a['time'] as num).compareTo(b['time'] as num));

      if (rawFrames.isEmpty) {
        return RadarTrackingResult.unavailable(
          'Radar nemá použiteľné historické snímky.',
        );
      }

      final selected = rawFrames.length <= _wantedFrames
          ? rawFrames
          : rawFrames.sublist(rawFrames.length - _wantedFrames);

      final kmPerPixel = _kmPerPixel(latitude, _zoom);
      final observations = <_RadarObservation>[];

      // Sequential downloading deliberately keeps request pressure low.
      for (final frame in selected) {
        final timestamp = DateTime.fromMillisecondsSinceEpoch(
          (frame['time'] as num).toInt() * 1000,
          isUtc: true,
        );
        final path = frame['path'].toString();

        final uri = Uri.parse(
          '$host$path/$_tileSize/$_zoom/'
          '${latitude.toStringAsFixed(6)}/'
          '${longitude.toStringAsFixed(6)}/'
          '$_colorScheme/0_0.png',
        );

        final response = await _client
            .get(uri)
            .timeout(const Duration(seconds: 12));

        if (response.statusCode != 200 || response.bodyBytes.isEmpty) {
          continue;
        }

        final observation = _analyseFrame(
          response.bodyBytes,
          timestamp,
          kmPerPixel,
        );
        if (observation != null) observations.add(observation);
      }

      if (observations.isEmpty) {
        // Radar itself was reachable; there simply may be no precipitation in
        // the coordinate-centred tile around the user.
        return RadarTrackingResult(
          generatedAt: DateTime.now(),
          radarAvailable: true,
          precipitationDetected: false,
          approaching: false,
          pathIntersectsUser: false,
          distanceKm: null,
          speedKmh: null,
          movementBearingDeg: null,
          precipitationBearingDeg: null,
          etaMinutes: null,
          confidence: 0.70,
          closestApproachKm: null,
          componentRadiusKm: null,
          framesUsed: selected.length,
          source: 'RainViewer',
          status: 'V okolí používateľa radar nezachytil zrážky.',
        );
      }

      final latest = observations.last;

      if (observations.length < 2) {
        return RadarTrackingResult(
          generatedAt: DateTime.now(),
          radarAvailable: true,
          precipitationDetected: true,
          approaching: false,
          pathIntersectsUser: false,
          distanceKm: latest.nearestEdgeKm,
          speedKmh: null,
          movementBearingDeg: null,
          precipitationBearingDeg: latest.nearestBearingDeg,
          etaMinutes: null,
          confidence: 0.25,
          closestApproachKm: null,
          componentRadiusKm: latest.radiusKm,
          framesUsed: 1,
          source: 'RainViewer',
          status: 'Zrážky sú na radare, ale chýba história pre spoľahlivý pohyb.',
        );
      }

      // Compare the oldest and latest usable observation. This smooths small
      // centroid jitter better than relying on a single 10-minute step.
      final oldest = observations.first;
      final dtHours = latest.time.difference(oldest.time).inSeconds / 3600.0;

      if (dtHours <= 0) {
        return RadarTrackingResult.unavailable(
          'Radarové snímky majú neplatný časový odstup.',
        );
      }

      final velocityEast =
          (latest.centroidEastKm - oldest.centroidEastKm) / dtHours;
      final velocityNorth =
          (latest.centroidNorthKm - oldest.centroidNorthKm) / dtHours;
      final speedKmh = math.sqrt(
        velocityEast * velocityEast + velocityNorth * velocityNorth,
      );

      // Very small apparent shifts are treated as stationary/uncertain rather
      // than inventing a direction from image jitter.
      final hasUsefulMotion = speedKmh >= 3.0 && speedKmh <= 180.0;
      final movementBearing = hasUsefulMotion
          ? _bearingFromVector(velocityEast, velocityNorth)
          : null;

      final rEast = latest.centroidEastKm;
      final rNorth = latest.centroidNorthKm;
      final v2 = velocityEast * velocityEast + velocityNorth * velocityNorth;

      double? closestApproachKm;
      double? hoursToClosest;
      if (hasUsefulMotion && v2 > 0) {
        hoursToClosest =
            -(rEast * velocityEast + rNorth * velocityNorth) / v2;
        if (hoursToClosest >= 0) {
          final closestEast = rEast + velocityEast * hoursToClosest;
          final closestNorth = rNorth + velocityNorth * hoursToClosest;
          closestApproachKm = math.sqrt(
            closestEast * closestEast + closestNorth * closestNorth,
          );
        }
      }

      final distanceTrend =
          oldest.nearestEdgeKm - latest.nearestEdgeKm; // + = approaching
      final approaching = hasUsefulMotion &&
          distanceTrend > math.max(0.8, kmPerPixel * 0.75) &&
          (hoursToClosest == null || hoursToClosest >= 0);

      // A component has spatial extent. We accept a path when the projected
      // centroid passes through the component radius plus a modest uncertainty
      // margin. This avoids claiming a hit from centroid motion alone.
      final pathIntersects = approaching &&
          closestApproachKm != null &&
          hoursToClosest != null &&
          hoursToClosest <= 1.5 &&
          closestApproachKm <= latest.radiusKm + 5.0;

      int? etaMinutes;
      if (pathIntersects && speedKmh > 0) {
        // nearestEdgeKm is a better first-drop estimate than centroid distance.
        final etaHours = latest.nearestEdgeKm / speedKmh;
        final rawMinutes = (etaHours * 60).round();
        if (rawMinutes >= 0 && rawMinutes <= 120) {
          etaMinutes = rawMinutes;
        }
      }

      final confidence = _confidence(
        observations: observations,
        latest: latest,
        speedKmh: speedKmh,
        hasUsefulMotion: hasUsefulMotion,
        distanceTrendKm: distanceTrend,
        pathIntersects: pathIntersects,
      );

      // Do not expose a precise ETA when confidence is too weak.
      if (confidence < 0.50) etaMinutes = null;

      final status = _statusText(
        precipitationDetected: true,
        hasUsefulMotion: hasUsefulMotion,
        approaching: approaching,
        pathIntersects: pathIntersects,
        etaMinutes: etaMinutes,
        confidence: confidence,
      );

      return RadarTrackingResult(
        generatedAt: DateTime.now(),
        radarAvailable: true,
        precipitationDetected: true,
        approaching: approaching,
        pathIntersectsUser: pathIntersects,
        distanceKm: latest.nearestEdgeKm,
        speedKmh: hasUsefulMotion ? speedKmh : null,
        movementBearingDeg: movementBearing,
        precipitationBearingDeg: latest.nearestBearingDeg,
        etaMinutes: etaMinutes,
        confidence: confidence,
        closestApproachKm: closestApproachKm,
        componentRadiusKm: latest.radiusKm,
        framesUsed: observations.length,
        source: 'RainViewer',
        status: status,
      );
    } catch (e) {
      return RadarTrackingResult.unavailable(
        'Radar tracking zlyhal: $e',
      );
    }
  }

  _RadarObservation? _analyseFrame(
    Uint8List bytes,
    DateTime time,
    double kmPerPixel,
  ) {
    final image = img.decodeImage(bytes);
    if (image == null || image.width < 8 || image.height < 8) return null;

    final width = image.width;
    final height = image.height;
    final cx = (width - 1) / 2.0;
    final cy = (height - 1) / 2.0;

    final wet = Uint8List(width * height);

    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final p = image.getPixel(x, y);
        final a = p.a.toDouble();
        final r = p.r.toDouble();
        final g = p.g.toDouble();
        final b = p.b.toDouble();

        // Radar tiles have transparent background. The RGB guard prevents a
        // fully transparent/black pixel from becoming precipitation due to a
        // decoder quirk.
        if (a >= 18 && (r + g + b) >= 18) {
          wet[y * width + x] = 1;
        }
      }
    }

    final visited = Uint8List(width * height);
    _Component? best;

    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final start = y * width + x;
        if (wet[start] == 0 || visited[start] != 0) continue;

        final component = _floodComponent(
          wet: wet,
          visited: visited,
          width: width,
          height: height,
          startX: x,
          startY: y,
          centerX: cx,
          centerY: cy,
        );

        if (component.count < _minimumComponentPixels) continue;

        if (best == null || component.nearestPixel2 < best.nearestPixel2) {
          best = component;
        }
      }
    }

    if (best == null) return null;

    final centroidX = best.sumX / best.count;
    final centroidY = best.sumY / best.count;

    final eastKm = (centroidX - cx) * kmPerPixel;
    final northKm = -(centroidY - cy) * kmPerPixel;

    final nearestEastKm = (best.nearestX - cx) * kmPerPixel;
    final nearestNorthKm = -(best.nearestY - cy) * kmPerPixel;

    final nearestEdgeKm = math.sqrt(best.nearestPixel2) * kmPerPixel;
    final nearestBearing =
        _bearingFromVector(nearestEastKm, nearestNorthKm);

    // Equivalent-area radius. Irregular bands are not circles, so this is used
    // only as a path-intersection tolerance, never shown as exact cell size.
    final areaKm2 = best.count * kmPerPixel * kmPerPixel;
    final radiusKm = math.sqrt(areaKm2 / math.pi);

    return _RadarObservation(
      time: time,
      centroidEastKm: eastKm,
      centroidNorthKm: northKm,
      nearestEdgeKm: nearestEdgeKm,
      nearestBearingDeg: nearestBearing,
      radiusKm: radiusKm,
      pixelCount: best.count,
    );
  }

  _Component _floodComponent({
    required Uint8List wet,
    required Uint8List visited,
    required int width,
    required int height,
    required int startX,
    required int startY,
    required double centerX,
    required double centerY,
  }) {
    final queue = <int>[startY * width + startX];
    visited[startY * width + startX] = 1;
    var head = 0;

    var count = 0;
    var sumX = 0.0;
    var sumY = 0.0;
    var nearest2 = double.infinity;
    var nearestX = startX;
    var nearestY = startY;

    const dx = <int>[-1, 0, 1, -1, 1, -1, 0, 1];
    const dy = <int>[-1, -1, -1, 0, 0, 1, 1, 1];

    while (head < queue.length) {
      final index = queue[head++];
      final x = index % width;
      final y = index ~/ width;

      count++;
      sumX += x;
      sumY += y;

      final ddx = x - centerX;
      final ddy = y - centerY;
      final d2 = ddx * ddx + ddy * ddy;
      if (d2 < nearest2) {
        nearest2 = d2;
        nearestX = x;
        nearestY = y;
      }

      for (var i = 0; i < 8; i++) {
        final nx = x + dx[i];
        final ny = y + dy[i];
        if (nx < 0 || ny < 0 || nx >= width || ny >= height) continue;
        final ni = ny * width + nx;
        if (wet[ni] == 0 || visited[ni] != 0) continue;
        visited[ni] = 1;
        queue.add(ni);
      }
    }

    return _Component(
      count: count,
      sumX: sumX,
      sumY: sumY,
      nearestPixel2: nearest2,
      nearestX: nearestX,
      nearestY: nearestY,
    );
  }

  double _confidence({
    required List<_RadarObservation> observations,
    required _RadarObservation latest,
    required double speedKmh,
    required bool hasUsefulMotion,
    required double distanceTrendKm,
    required bool pathIntersects,
  }) {
    var score = 0.20;

    if (observations.length >= 2) score += 0.15;
    if (observations.length >= 3) score += 0.15;
    if (observations.length >= 4) score += 0.10;
    if (latest.pixelCount >= 12) score += 0.08;
    if (latest.pixelCount >= 40) score += 0.07;
    if (hasUsefulMotion) score += 0.10;
    if (distanceTrendKm.abs() >= 1.0) score += 0.05;
    if (pathIntersects) score += 0.05;

    // Implausibly fast image motion is often a component-match failure.
    if (speedKmh > 120) score -= 0.15;

    return score.clamp(0.0, 0.95).toDouble();
  }

  String _statusText({
    required bool precipitationDetected,
    required bool hasUsefulMotion,
    required bool approaching,
    required bool pathIntersects,
    required int? etaMinutes,
    required double confidence,
  }) {
    if (!precipitationDetected) {
      return 'Radar v okolí nezachytil zrážky.';
    }
    if (!hasUsefulMotion) {
      return 'Radar zachytil zrážky, ale pohyb zatiaľ nie je spoľahlivý.';
    }
    if (!approaching) {
      return 'Radar zachytil zrážky, ale aktuálne sa k tvojej polohe nepribližujú.';
    }
    if (!pathIntersects) {
      return 'Zrážky sa približujú, ale aktuálna radarová dráha tvoju polohu nepretína.';
    }
    if (confidence < 0.50 || etaMinutes == null) {
      return 'Zrážky smerujú k tvojej polohe, ale radarový track má zatiaľ nízku istotu.';
    }
    return 'Radar sleduje zrážky smerujúce k tvojej polohe. Odhad ETA: $etaMinutes min.';
  }

  static double _kmPerPixel(double latitude, int zoom) {
    const earthCircumferenceKm = 40075.016686;
    final latRad = latitude * math.pi / 180.0;
    return earthCircumferenceKm * math.cos(latRad) /
        (_tileSize * math.pow(2.0, zoom));
  }

  static double _bearingFromVector(double east, double north) {
    var deg = math.atan2(east, north) * 180.0 / math.pi;
    if (deg < 0) deg += 360.0;
    return deg;
  }
}

class _RadarObservation {
  final DateTime time;
  final double centroidEastKm;
  final double centroidNorthKm;
  final double nearestEdgeKm;
  final double nearestBearingDeg;
  final double radiusKm;
  final int pixelCount;

  const _RadarObservation({
    required this.time,
    required this.centroidEastKm,
    required this.centroidNorthKm,
    required this.nearestEdgeKm,
    required this.nearestBearingDeg,
    required this.radiusKm,
    required this.pixelCount,
  });
}

class _Component {
  final int count;
  final double sumX;
  final double sumY;
  final double nearestPixel2;
  final int nearestX;
  final int nearestY;

  const _Component({
    required this.count,
    required this.sumX,
    required this.sumY,
    required this.nearestPixel2,
    required this.nearestX,
    required this.nearestY,
  });
}
