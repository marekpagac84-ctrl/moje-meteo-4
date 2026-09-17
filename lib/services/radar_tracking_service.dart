import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;

/// Experimental real-radar tracker using RainViewer radar frames.
///
/// IMPORTANT: RainViewer's public API is intended for personal/educational/
/// small-community use. Before commercial release, replace the provider or
/// arrange commercial terms. The tracking maths is provider-independent.
class RadarTrackingResult {
  final bool available;
  final DateTime? radarTime;
  final double? distanceKm;
  final double? bearingFromUser;
  final double? motionDirection;
  final double? speedKmh;
  final int? etaMinutes;
  final double? closestApproachKm;
  final double? intensityScore;
  final double confidence;
  final bool movingTowardUser;
  final String status;

  const RadarTrackingResult({
    required this.available,
    required this.radarTime,
    required this.distanceKm,
    required this.bearingFromUser,
    required this.motionDirection,
    required this.speedKmh,
    required this.etaMinutes,
    required this.closestApproachKm,
    required this.intensityScore,
    required this.confidence,
    required this.movingTowardUser,
    required this.status,
  });

  const RadarTrackingResult.unavailable(String reason)
      : available = false,
        radarTime = null,
        distanceKm = null,
        bearingFromUser = null,
        motionDirection = null,
        speedKmh = null,
        etaMinutes = null,
        closestApproachKm = null,
        intensityScore = null,
        confidence = 0,
        movingTowardUser = false,
        status = reason;
}

class _RadarFrame {
  final DateTime time;
  final _RadarCell? cell;
  const _RadarFrame(this.time, this.cell);
}

class _RadarCell {
  final double eastKm;
  final double northKm;
  final double edgeDistanceKm;
  final double radiusKm;
  final double intensity;
  final int points;

  const _RadarCell({
    required this.eastKm,
    required this.northKm,
    required this.edgeDistanceKm,
    required this.radiusKm,
    required this.intensity,
    required this.points,
  });

  double get centerDistanceKm => math.sqrt(eastKm * eastKm + northKm * northKm);
}

class RadarTrackingService {
  static const String _timelineUrl =
      'https://api.rainviewer.com/public/weather-maps.json';
  static const int _zoom = 7;
  static const int _size = 512;
  static const int _step = 4; // analyse 128x128 samples instead of every pixel

  Future<RadarTrackingResult> track({
    required double latitude,
    required double longitude,
  }) async {
    try {
      final response = await http
          .get(Uri.parse(_timelineUrl))
          .timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) {
        return RadarTrackingResult.unavailable('Radar API HTTP ${response.statusCode}');
      }

      final root = jsonDecode(response.body) as Map<String, dynamic>;
      final host = root['host']?.toString();
      final radar = root['radar'] as Map<String, dynamic>?;
      final past = (radar?['past'] as List?)?.cast<dynamic>() ?? const [];
      if (host == null || past.isEmpty) {
        return const RadarTrackingResult.unavailable('Radar nemá dostupné snímky');
      }

      // Four recent frames give us roughly 30 minutes of observed motion.
      final selected = past.length <= 4 ? past : past.sublist(past.length - 4);
      final frames = <_RadarFrame>[];
      for (final raw in selected) {
        final map = raw as Map<String, dynamic>;
        final path = map['path']?.toString();
        final unix = (map['time'] as num?)?.toInt();
        if (path == null || unix == null) continue;

        final uri = Uri.parse(
          '$host$path/$_size/$_zoom/${latitude.toStringAsFixed(5)}/${longitude.toStringAsFixed(5)}/2/0_0.png',
        );
        final tile = await http.get(uri).timeout(const Duration(seconds: 8));
        if (tile.statusCode != 200 || tile.bodyBytes.isEmpty) continue;
        final decoded = img.decodeImage(Uint8List.fromList(tile.bodyBytes));
        if (decoded == null) continue;
        frames.add(_RadarFrame(
          DateTime.fromMillisecondsSinceEpoch(unix * 1000, isUtc: true).toLocal(),
          _findRelevantCell(decoded, latitude),
        ));
      }

      final usable = frames.where((f) => f.cell != null).toList();
      if (usable.isEmpty) {
        return RadarTrackingResult(
          available: true,
          radarTime: frames.isEmpty ? null : frames.last.time,
          distanceKm: null,
          bearingFromUser: null,
          motionDirection: null,
          speedKmh: null,
          etaMinutes: null,
          closestApproachKm: null,
          intensityScore: null,
          confidence: 0.55,
          movingTowardUser: false,
          status: 'V okolí približne 100 km radar nevidí súvislé zrážkové jadro.',
        );
      }

      final latest = usable.last;
      final cell = latest.cell!;
      final bearing = _bearing(cell.eastKm, cell.northKm);

      // Match the same cell backwards by centroid proximity. We deliberately
      // reject large jumps so another nearby shower does not become its history.
      final history = <_RadarFrame>[latest];
      var target = cell;
      for (var i = usable.length - 2; i >= 0; i--) {
        final candidate = usable[i].cell!;
        final separation = _distance(
          target.eastKm, target.northKm, candidate.eastKm, candidate.northKm,
        );
        if (separation <= 45.0) {
          history.insert(0, usable[i]);
          target = candidate;
        }
      }

      double? speed;
      double? motionDirection;
      double? closest;
      int? eta;
      bool toward = false;
      double confidence = 0.58;

      if (history.length >= 2) {
        final first = history.first;
        final last = history.last;
        final dtHours = last.time.difference(first.time).inSeconds / 3600.0;
        if (dtHours > 0) {
          final vx = (last.cell!.eastKm - first.cell!.eastKm) / dtHours;
          final vy = (last.cell!.northKm - first.cell!.northKm) / dtHours;
          final rawSpeed = math.sqrt(vx * vx + vy * vy);

          // Plausibility guard against cell mismatches / image artefacts.
          if (rawSpeed >= 2 && rawSpeed <= 160) {
            speed = rawSpeed;
            motionDirection = _bearing(vx, vy);
            final d = math.max(0.1, cell.centerDistanceKm);
            final radialVelocity = (cell.eastKm * vx + cell.northKm * vy) / d;
            final closingKmh = -radialVelocity;
            toward = closingKmh > 2.0;

            // Closest approach of the cell centroid to the user.
            final v2 = vx * vx + vy * vy;
            final tClosestHours = v2 <= 0
                ? 0.0
                : math.max(0.0, -(cell.eastKm * vx + cell.northKm * vy) / v2);
            final closestEast = cell.eastKm + vx * tClosestHours;
            final closestNorth = cell.northKm + vy * tClosestHours;
            closest = math.sqrt(closestEast * closestEast + closestNorth * closestNorth);

            // ETA uses the observed leading edge, not the centroid. Only show
            // impact ETA when the extrapolated track intersects the cell radius
            // plus a small uncertainty corridor.
            final corridorKm = math.max(6.0, cell.radiusKm + 4.0);
            if (toward && closest <= corridorKm && closingKmh > 0) {
              eta = (cell.edgeDistanceKm / closingKmh * 60).round();
              if (eta < 0 || eta > 180) eta = null;
            }
            confidence = history.length >= 4 ? 0.84 : history.length == 3 ? 0.76 : 0.67;
          }
        }
      }

      final status = eta != null
          ? 'Radarové jadro sa podľa posledných snímok približuje k tvojej polohe.'
          : speed != null && toward
              ? 'Radarové jadro sa približuje, ale jeho aktuálna dráha nemusí zasiahnuť tvoju polohu.'
              : speed != null
                  ? 'Radarové jadro je v okolí, no podľa posledných snímok sa k tvojej polohe nepribližuje.'
                  : 'Radar vidí zrážky, ale zatiaľ nemáme dosť snímok na spoľahlivý vektor pohybu.';

      return RadarTrackingResult(
        available: true,
        radarTime: latest.time,
        distanceKm: cell.edgeDistanceKm,
        bearingFromUser: bearing,
        motionDirection: motionDirection,
        speedKmh: speed,
        etaMinutes: eta,
        closestApproachKm: closest,
        intensityScore: cell.intensity,
        confidence: confidence,
        movingTowardUser: toward,
        status: status,
      );
    } catch (e) {
      return RadarTrackingResult.unavailable('Radar tracking dočasne nedostupný: $e');
    }
  }

  _RadarCell? _findRelevantCell(img.Image image, double latitude) {
    final w = image.width;
    final h = image.height;
    if (w < 32 || h < 32) return null;

    final cols = (w / _step).floor();
    final rows = (h / _step).floor();
    final wet = List<bool>.filled(cols * rows, false);
    final intensity = List<double>.filled(cols * rows, 0);

    for (var gy = 0; gy < rows; gy++) {
      for (var gx = 0; gx < cols; gx++) {
        final p = image.getPixel(
          math.min(w - 1, gx * _step + _step ~/ 2),
          math.min(h - 1, gy * _step + _step ~/ 2),
        );
        final a = p.a.toDouble();
        // Universal Blue is transparent for no echo; alpha rises with echo.
        // Ignore the very faintest echoes/noise.
        if (a >= 28) {
          final idx = gy * cols + gx;
          wet[idx] = true;
          intensity[idx] = a / 255.0;
        }
      }
    }

    final visited = List<bool>.filled(wet.length, false);
    final cells = <_RadarCell>[];
    final kmPerPixel =
        (40075.016686 * math.cos(latitude * math.pi / 180.0)) /
            (math.pow(2.0, _zoom) * _size);
    final kmPerSample = kmPerPixel * _step;
    final centerX = (cols - 1) / 2.0;
    final centerY = (rows - 1) / 2.0;

    const dirs = <List<int>>[
      [1, 0], [-1, 0], [0, 1], [0, -1],
      [1, 1], [1, -1], [-1, 1], [-1, -1],
    ];

    for (var sy = 0; sy < rows; sy++) {
      for (var sx = 0; sx < cols; sx++) {
        final start = sy * cols + sx;
        if (!wet[start] || visited[start]) continue;

        final queueX = <int>[sx];
        final queueY = <int>[sy];
        visited[start] = true;
        var head = 0;
        var count = 0;
        var sumX = 0.0;
        var sumY = 0.0;
        var sumI = 0.0;
        var minDist = double.infinity;
        var maxRadius = 0.0;

        while (head < queueX.length) {
          final x = queueX[head];
          final y = queueY[head];
          head++;
          final idx = y * cols + x;
          count++;
          sumX += x;
          sumY += y;
          sumI += intensity[idx];
          final dx = (x - centerX) * kmPerSample;
          final dy = (centerY - y) * kmPerSample;
          final d = math.sqrt(dx * dx + dy * dy);
          if (d < minDist) minDist = d;

          for (final dir in dirs) {
            final nx = x + dir[0];
            final ny = y + dir[1];
            if (nx < 0 || ny < 0 || nx >= cols || ny >= rows) continue;
            final ni = ny * cols + nx;
            if (wet[ni] && !visited[ni]) {
              visited[ni] = true;
              queueX.add(nx);
              queueY.add(ny);
            }
          }
        }

        // Remove isolated pixels / tiny radar speckle.
        if (count < 4) continue;
        final cx = sumX / count;
        final cy = sumY / count;
        final east = (cx - centerX) * kmPerSample;
        final north = (centerY - cy) * kmPerSample;
        final areaKm2 = count * kmPerSample * kmPerSample;
        maxRadius = math.sqrt(areaKm2 / math.pi);
        cells.add(_RadarCell(
          eastKm: east,
          northKm: north,
          edgeDistanceKm: minDist,
          radiusKm: maxRadius,
          intensity: sumI / count,
          points: count,
        ));
      }
    }

    if (cells.isEmpty) return null;
    // Prefer a nearby meaningful area. Larger/intense cells win ties, but a
    // huge distant system does not hide a small shower about to reach the user.
    cells.sort((a, b) {
      final scoreA = a.edgeDistanceKm - math.min(15.0, a.radiusKm) - a.intensity * 8.0;
      final scoreB = b.edgeDistanceKm - math.min(15.0, b.radiusKm) - b.intensity * 8.0;
      return scoreA.compareTo(scoreB);
    });
    return cells.first;
  }

  static double _distance(double ax, double ay, double bx, double by) {
    final dx = ax - bx;
    final dy = ay - by;
    return math.sqrt(dx * dx + dy * dy);
  }

  static double _bearing(double east, double north) {
    var degrees = math.atan2(east, north) * 180.0 / math.pi;
    if (degrees < 0) degrees += 360.0;
    return degrees;
  }
}
