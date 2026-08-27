import 'dart:math' as math;

import 'package:flutter/material.dart';

class WeatherSceneBackground extends StatelessWidget {
  final int weatherCode;
  final bool isNight;
  final double temperature;
  final bool rainExpected;
  final double animation;
  final double heading;

  const WeatherSceneBackground({
    super.key,
    required this.weatherCode,
    required this.isNight,
    required this.temperature,
    required this.rainExpected,
    required this.animation,
    required this.heading,
  });

  String get assetPath {
    final now = DateTime.now();
    final hour = now.hour + now.minute / 60.0;

    final snow = <int>{71, 73, 75, 77, 85, 86}.contains(weatherCode);
    final rain = <int>{51, 53, 55, 56, 57, 61, 63, 65, 66, 67, 80, 81, 82}.contains(weatherCode);
    final storm = <int>{95, 96, 99}.contains(weatherCode);
    final fog = weatherCode == 45 || weatherCode == 48;

    if (isNight) {
      if (snow || temperature <= -1.0) {
        return 'assets/scenes/12_winter_night.jpg';
      }
      if (rain || storm || rainExpected) {
        return 'assets/scenes/11_rainy_night.jpg';
      }
      return 'assets/scenes/10_clear_night.jpg';
    }

    if (snow) return 'assets/scenes/07_snow.jpg';
    if (storm) return 'assets/scenes/05_storm.jpg';
    if (rain) return 'assets/scenes/04_rain.jpg';
    if (fog) return 'assets/scenes/06_fog.jpg';

    if (hour >= 5.0 && hour < 7.5) {
      return 'assets/scenes/09_sunrise.jpg';
    }
    if (hour >= 17.5 && hour < 20.5) {
      return 'assets/scenes/08_sunset.jpg';
    }

    if (weatherCode == 0) return 'assets/scenes/01_sunny.jpg';
    if (weatherCode == 1 || weatherCode == 2) {
      return 'assets/scenes/02_partly_cloudy.jpg';
    }
    if (weatherCode == 3) return 'assets/scenes/03_cloudy.jpg';

    return rainExpected
        ? 'assets/scenes/02_partly_cloudy.jpg'
        : 'assets/scenes/01_sunny.jpg';
  }

  bool get _rainy =>
      rainExpected ||
      <int>{51, 53, 55, 56, 57, 61, 63, 65, 66, 67, 80, 81, 82, 95, 96, 99}
          .contains(weatherCode);

  bool get _storm => <int>{95, 96, 99}.contains(weatherCode);
  bool get _snow => <int>{71, 73, 75, 77, 85, 86}.contains(weatherCode);
  bool get _fog => weatherCode == 45 || weatherCode == 48;

  @override
  Widget build(BuildContext context) {
    final phase = animation * math.pi * 2.0;
    final headingShift = math.sin(heading * math.pi / 180.0) * 5.0;

    return Stack(
      fit: StackFit.expand,
      children: [
        ClipRect(
          child: Transform.translate(
            offset: Offset(
              math.sin(phase * 0.55) * 2.8 + headingShift,
              math.cos(phase * 0.45) * 1.5,
            ),
            child: Transform.scale(
              scale: 1.075 + math.sin(phase * 0.35) * 0.006,
              child: Image.asset(
                assetPath,
                fit: BoxFit.cover,
                alignment: Alignment.center,
                filterQuality: FilterQuality.high,
              ),
            ),
          ),
        ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0x4D00111E),
                Color(0x05000000),
                Color(0x5C00101C),
              ],
              stops: [0.0, 0.46, 1.0],
            ),
          ),
        ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0x18000000),
                Color(0x00000000),
                Color(0x7A001019),
              ],
              stops: [0.0, 0.48, 1.0],
            ),
          ),
        ),
        if (_fog)
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  Color(0x33FFFFFF),
                  Color(0x12FFFFFF),
                  Color(0x2BFFFFFF),
                ],
              ),
            ),
          ),
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: _WeatherFxPainter(
                phase: phase,
                rain: _rainy && !_snow,
                snow: _snow,
                storm: _storm,
                night: isNight,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _WeatherFxPainter extends CustomPainter {
  final double phase;
  final bool rain;
  final bool snow;
  final bool storm;
  final bool night;

  const _WeatherFxPainter({
    required this.phase,
    required this.rain,
    required this.snow,
    required this.storm,
    required this.night,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (rain) {
      final paint = Paint()
        ..color = Colors.white.withOpacity(night ? 0.16 : 0.20)
        ..strokeWidth = 1.15
        ..strokeCap = StrokeCap.round;
      for (int i = 0; i < 34; i++) {
        final baseX = ((i * 47.0) + phase * 19.0) % (size.width + 35) - 15;
        final baseY = ((i * 73.0) + phase * 53.0) % (size.height + 55) - 25;
        final length = 14.0 + (i % 5) * 2.4;
        canvas.drawLine(
          Offset(baseX, baseY),
          Offset(baseX - 4.5, baseY + length),
          paint,
        );
      }
    }

    if (snow) {
      final paint = Paint()..color = Colors.white.withOpacity(0.72);
      for (int i = 0; i < 30; i++) {
        final drift = math.sin(phase + i * 0.7) * 9.0;
        final x = ((i * 61.0) + drift) % (size.width + 20) - 10;
        final y = ((i * 43.0) + phase * 23.0) % (size.height + 25) - 12;
        canvas.drawCircle(Offset(x, y), 1.2 + (i % 4) * 0.55, paint);
      }
    }

    if (storm) {
      final pulse = math.sin(phase * 3.0);
      if (pulse > 0.92) {
        final flash = Paint()
          ..color = Colors.white.withOpacity((pulse - 0.92) * 3.0)
          ..blendMode = BlendMode.screen;
        canvas.drawRect(Offset.zero & size, flash);
      }
      if (math.sin(phase * 1.65) > 0.94) {
        final bolt = Paint()
          ..color = const Color(0xFFFFF6BD).withOpacity(0.72)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2
          ..strokeCap = StrokeCap.round;
        final path = Path()
          ..moveTo(size.width * 0.73, size.height * 0.10)
          ..lineTo(size.width * 0.66, size.height * 0.28)
          ..lineTo(size.width * 0.71, size.height * 0.28)
          ..lineTo(size.width * 0.62, size.height * 0.51);
        canvas.drawPath(path, bolt);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _WeatherFxPainter oldDelegate) {
    return phase != oldDelegate.phase ||
        rain != oldDelegate.rain ||
        snow != oldDelegate.snow ||
        storm != oldDelegate.storm ||
        night != oldDelegate.night;
  }
}
