import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/weather_intelligence_service.dart';

class StormOrbWidget extends StatefulWidget {
  final WeatherIntelligenceResult? intelligence;
  final double temperature;
  final double? apparentTemperature;
  final String locationName;
  final double heading;
  final int? rainProbability;
  final double? rainTotalMm;
  final DateTime? updatedAt;
  final VoidCallback? onRefresh;
  final VoidCallback? onRadar;
  final VoidCallback? onAiSky;
  final VoidCallback? onDetail;
  final VoidCallback? onMap;

  const StormOrbWidget({
    super.key,
    required this.intelligence,
    required this.temperature,
    required this.locationName,
    required this.heading,
    this.apparentTemperature,
    this.rainProbability,
    this.rainTotalMm,
    this.updatedAt,
    this.onRefresh,
    this.onRadar,
    this.onAiSky,
    this.onDetail,
    this.onMap,
  });

  @override
  State<StormOrbWidget> createState() => _StormOrbWidgetState();
}

class _StormOrbWidgetState extends State<StormOrbWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _clock(DateTime value) =>
      '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final result = widget.intelligence;
    final now = DateTime.now();
    final probability = widget.rainProbability ?? result?.rainProbability;
    final eta = result?.radarEtaMinutes;
    final distance = result?.radarDistanceKm;
    final speed = result?.radarSpeedKmh;
    final confidence = result?.radarConfidence;

    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF07131F),
              Color(0xFF0A2232),
              Color(0xFF071018),
            ],
          ),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _AtmospherePainter(
                  storm: result?.stormNearby ?? false,
                  rain: result?.rainNearby ?? false,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _clock(now),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 46,
                                height: 0.95,
                                fontWeight: FontWeight.w300,
                                letterSpacing: -2,
                              ),
                            ),
                            const SizedBox(height: 7),
                            Row(
                              children: [
                                const Icon(Icons.location_on_outlined,
                                    color: Color(0xFF8DDCFF), size: 15),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    widget.locationName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Color(0xFFD6ECF7),
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      _GlassBox(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '${widget.temperature.round()}°',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 31,
                                fontWeight: FontWeight.w300,
                              ),
                            ),
                            if (widget.apparentTemperature != null)
                              Text(
                                'Pocitovo ${widget.apparentTemperature!.round()}°',
                                style: const TextStyle(
                                  color: Color(0xFFB8CDD8),
                                  fontSize: 11,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _GlassBox(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                    child: Row(
                      children: [
                        const Icon(Icons.water_drop_outlined,
                            color: Color(0xFF67D4FF), size: 20),
                        const SizedBox(width: 9),
                        const Expanded(
                          child: Text(
                            'Pravdepodobnosť zrážok v tvojej polohe',
                            style: TextStyle(
                              color: Color(0xFFD7EAF4),
                              fontSize: 12,
                            ),
                          ),
                        ),
                        Text(
                          probability == null ? '-- %' : '$probability %',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 23,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final size = math.min(constraints.maxWidth,
                            constraints.maxHeight * 0.88);
                        return Center(
                          child: SizedBox(
                            width: size,
                            height: size,
                            child: AnimatedBuilder(
                              animation: _controller,
                              builder: (context, _) => CustomPaint(
                                painter: _StormOrbPainter(
                                  heading: widget.heading,
                                  precipitationBearing:
                                      result?.radarPrecipitationBearingDeg,
                                  movementBearing:
                                      result?.radarMovementBearingDeg,
                                  distanceKm: distance,
                                  approaching: result?.radarApproaching ?? false,
                                  intersects:
                                      result?.radarPathIntersectsUser ?? false,
                                  confidence: confidence ?? 0,
                                  pulse: _controller.value,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  Center(
                    child: Column(
                      children: [
                        Text(
                          (result?.rainingAtUser ?? false)
                              ? 'AKTUÁLNE PRŠÍ V TVOJEJ POLOHE'
                              : eta != null && (result?.radarPathIntersectsUser ?? false)
                              ? 'DÁŽĎ ZA $eta MIN'
                              : (result?.radarApproaching ?? false)
                                  ? 'ZRÁŽKY SA PRIBLIŽUJÚ'
                                  : 'RADAR SLEDUJE OKOLIE',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 21,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.4,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _directionLine(result),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0xFF82DFFF),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _GlassBox(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                    child: Row(
                      children: [
                        _Metric('Vzdialenosť',
                            distance == null ? '--' : '${distance.toStringAsFixed(1)} km'),
                        _divider(),
                        _Metric('Rýchlosť',
                            speed == null ? '--' : '${speed.round()} km/h'),
                        _divider(),
                        _Metric('ETA', eta == null ? '--' : '$eta min'),
                        _divider(),
                        _Metric('Úhrn', widget.rainTotalMm == null
                            ? '--'
                            : '${widget.rainTotalMm!.toStringAsFixed(1)} mm'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _Action(icon: Icons.radar, label: 'Radar', onTap: widget.onRadar),
                      _Action(icon: Icons.camera_alt_outlined, label: 'AI SKY', onTap: widget.onAiSky),
                      _Action(icon: Icons.insights_outlined, label: 'Detail', onTap: widget.onDetail),
                      _Action(icon: Icons.map_outlined, label: 'Mapa', onTap: widget.onMap),
                      _Action(icon: Icons.refresh, label: 'Obnoviť', onTap: widget.onRefresh),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _confidenceColor(confidence),
                          boxShadow: const [
                            BoxShadow(color: Color(0xAA6BD9FF), blurRadius: 8),
                          ],
                        ),
                      ),
                      const SizedBox(width: 7),
                      Text(
                        'Radar confidence ${confidence == null ? '--' : '${(confidence * 100).round()} %'}  •  Aktualizované ${_clock(widget.updatedAt ?? now)}',
                        style: const TextStyle(
                          color: Color(0xFF91A9B6),
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _divider() => Container(
        width: 1,
        height: 31,
        color: const Color(0x22FFFFFF),
      );

  static Color _confidenceColor(double? confidence) {
    if (confidence == null) return const Color(0xFF78909C);
    if (confidence >= 0.7) return const Color(0xFF6EE7B7);
    if (confidence >= 0.45) return const Color(0xFFFFD166);
    return const Color(0xFFFF8A80);
  }

  static String _directionLine(WeatherIntelligenceResult? result) {
    if (result?.rainingAtUser == true) {
      return 'Radar/model potvrdzuje zrážky priamo nad tebou';
    }
    if (result == null || result.radarPrecipitationBearingDeg == null) {
      return 'Čakám na spoľahlivý radarový track';
    }
    final bearing = result.radarPrecipitationBearingDeg!;
    return 'Zrážky ${_compass(bearing)} (${bearing.round()}°)'
        '${result.radarPathIntersectsUser ? ' • dráha pretína tvoju polohu' : ''}';
  }

  static String _compass(double deg) {
    const names = ['S', 'SV', 'V', 'JV', 'J', 'JZ', 'Z', 'SZ'];
    return names[((deg + 22.5) ~/ 45) % 8];
  }
}

class _GlassBox extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;

  const _GlassBox({
    required this.child,
    this.padding = const EdgeInsets.all(12),
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: padding,
        decoration: BoxDecoration(
          color: const Color(0x28132635),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0x2FFFFFFF)),
          boxShadow: const [
            BoxShadow(color: Color(0x25000000), blurRadius: 18, offset: Offset(0, 8)),
          ],
        ),
        child: child,
      );
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;

  const _Metric(this.label, this.value);

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(
          children: [
            Text(label,
                style: const TextStyle(color: Color(0xFF8FA9B7), fontSize: 9)),
            const SizedBox(height: 3),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(value,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      );
}

class _Action extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _Action({required this.icon, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) => Expanded(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              children: [
                Icon(icon, color: const Color(0xFF8ADFFF), size: 20),
                const SizedBox(height: 3),
                Text(label,
                    maxLines: 1,
                    style: const TextStyle(color: Color(0xFFCFE6F1), fontSize: 9)),
              ],
            ),
          ),
        ),
      );
}

class _StormOrbPainter extends CustomPainter {
  final double heading;
  final double? precipitationBearing;
  final double? movementBearing;
  final double? distanceKm;
  final bool approaching;
  final bool intersects;
  final double confidence;
  final double pulse;

  _StormOrbPainter({
    required this.heading,
    required this.precipitationBearing,
    required this.movementBearing,
    required this.distanceKm,
    required this.approaching,
    required this.intersects,
    required this.confidence,
    required this.pulse,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) * 0.43;

    final glow = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0x5538C8FF),
          const Color(0x221B789B),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius * 1.35));
    canvas.drawCircle(center, radius * 1.35, glow);

    final sphere = Paint()
      ..shader = const RadialGradient(
        center: Alignment(-0.35, -0.4),
        radius: 1.05,
        colors: [Color(0xCC1A5872), Color(0xDD0A2A3D), Color(0xFF04131E)],
        stops: [0, 0.58, 1],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, sphere);

    canvas.save();
    canvas.clipPath(Path()..addOval(Rect.fromCircle(center: center, radius: radius)));

    final grid = Paint()
      ..color = const Color(0x335BD8FF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (final f in [0.25, 0.5, 0.75, 1.0]) {
      canvas.drawCircle(center, radius * f, grid);
    }
    for (int i = 0; i < 12; i++) {
      final a = i * math.pi / 6;
      canvas.drawLine(center,
          center + Offset(math.sin(a), -math.cos(a)) * radius, grid);
    }

    if (precipitationBearing != null) {
      final relative = _rad(precipitationBearing! - heading);
      final normalizedDistance = ((distanceKm ?? 18) / 50).clamp(0.18, 0.9);
      final cellCenter = center +
          Offset(math.sin(relative), -math.cos(relative)) *
              radius * normalizedDistance;
      final cloudRadius = radius * (0.18 + confidence * 0.08);
      final rainPaint = Paint()
        ..shader = RadialGradient(
          colors: intersects
              ? const [Color(0xEEFFCC4D), Color(0xCCFF7043), Color(0x6639C5FF), Colors.transparent]
              : const [Color(0xDD63E6FF), Color(0xAA278CC5), Color(0x443A77FF), Colors.transparent],
          stops: const [0, 0.28, 0.67, 1],
        ).createShader(Rect.fromCircle(center: cellCenter, radius: cloudRadius));
      canvas.drawCircle(cellCenter, cloudRadius, rainPaint);
      canvas.drawCircle(cellCenter + Offset(cloudRadius * .5, cloudRadius * .2),
          cloudRadius * .75, rainPaint);
      canvas.drawCircle(cellCenter + Offset(-cloudRadius * .45, -cloudRadius * .18),
          cloudRadius * .65, rainPaint);

      if (movementBearing != null) {
        final moveRelative = _rad(movementBearing! - heading);
        final from = cellCenter;
        final to = from + Offset(math.sin(moveRelative), -math.cos(moveRelative)) * radius * .36;
        final arrow = Paint()
          ..color = approaching ? const Color(0xFFFFE082) : const Color(0xFF82DFFF)
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(from, to, arrow);
        _arrowHead(canvas, to, moveRelative, arrow);
      }
    }

    final sweep = Paint()
      ..shader = SweepGradient(
        startAngle: 0,
        endAngle: math.pi * 2,
        colors: const [Colors.transparent, Color(0x2239D6FF), Color(0x9939D6FF), Colors.transparent],
        stops: const [0, .78, .94, 1],
        transform: GradientRotation(pulse * math.pi * 2),
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, sweep);
    canvas.restore();

    final rim = Paint()
      ..color = const Color(0x8858D7FF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(center, radius, rim);

    final userGlow = Paint()..color = const Color(0x5549D8FF);
    canvas.drawCircle(center, 10 + 3 * math.sin(pulse * math.pi * 2), userGlow);
    canvas.drawCircle(center, 4.5, Paint()..color = const Color(0xFF7CE7FF));
    _text(canvas, 'TY', center + const Offset(0, 9), 10, Colors.white, true);

    _text(canvas, 'PRED TEBOU', center + Offset(0, -radius - 17), 8,
        const Color(0xFF9DDFF6), true);
    _text(canvas, 'ZA TEBOU', center + Offset(0, radius + 9), 8,
        const Color(0xFF7E9CAA), false);
    _text(canvas, 'VĽAVO', center + Offset(-radius - 24, -3), 8,
        const Color(0xFF7E9CAA), false);
    _text(canvas, 'VPRAVO', center + Offset(radius + 24, -3), 8,
        const Color(0xFF7E9CAA), false);
  }

  double _rad(double deg) => deg * math.pi / 180;

  void _arrowHead(Canvas canvas, Offset tip, double angle, Paint paint) {
    const len = 10.0;
    final a1 = angle + math.pi * .78;
    final a2 = angle - math.pi * .78;
    canvas.drawLine(tip, tip + Offset(math.sin(a1), -math.cos(a1)) * len, paint);
    canvas.drawLine(tip, tip + Offset(math.sin(a2), -math.cos(a2)) * len, paint);
  }

  void _text(Canvas canvas, String value, Offset at, double size, Color color, bool bold) {
    final tp = TextPainter(
      text: TextSpan(
        text: value,
        style: TextStyle(
          color: color,
          fontSize: size,
          fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, at - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant _StormOrbPainter oldDelegate) =>
      oldDelegate.heading != heading ||
      oldDelegate.precipitationBearing != precipitationBearing ||
      oldDelegate.movementBearing != movementBearing ||
      oldDelegate.distanceKm != distanceKm ||
      oldDelegate.approaching != approaching ||
      oldDelegate.intersects != intersects ||
      oldDelegate.confidence != confidence ||
      oldDelegate.pulse != pulse;
}

class _AtmospherePainter extends CustomPainter {
  final bool storm;
  final bool rain;

  _AtmospherePainter({required this.storm, required this.rain});

  @override
  void paint(Canvas canvas, Size size) {
    final horizon = size.height * .72;
    final mountain = Paint()..color = const Color(0x55101F26);
    final path = Path()
      ..moveTo(0, horizon)
      ..lineTo(size.width * .18, horizon - 34)
      ..lineTo(size.width * .34, horizon - 8)
      ..lineTo(size.width * .55, horizon - 52)
      ..lineTo(size.width * .76, horizon - 18)
      ..lineTo(size.width, horizon - 46)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(path, mountain);

    if (rain) {
      final drops = Paint()
        ..color = const Color(0x226DDCFF)
        ..strokeWidth = 1;
      for (int i = 0; i < 34; i++) {
        final x = ((i * 47) % 101) / 100 * size.width;
        final y = ((i * 83) % 67) / 67 * size.height;
        canvas.drawLine(Offset(x, y), Offset(x - 3, y + 12), drops);
      }
    }

    if (storm) {
      final flash = Paint()
        ..shader = const RadialGradient(
          colors: [Color(0x226FD9FF), Colors.transparent],
        ).createShader(Rect.fromCircle(
          center: Offset(size.width * .78, size.height * .2),
          radius: size.width * .35,
        ));
      canvas.drawCircle(Offset(size.width * .78, size.height * .2),
          size.width * .35, flash);
    }
  }

  @override
  bool shouldRepaint(covariant _AtmospherePainter oldDelegate) =>
      oldDelegate.storm != storm || oldDelegate.rain != rain;
}
