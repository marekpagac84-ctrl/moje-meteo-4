import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

class CloudClassificationResult {
  final String name;
  final String code;
  final double confidence;

  const CloudClassificationResult({
    required this.name,
    required this.code,
    required this.confidence,
  });

  bool get isCumulonimbus => code == 'Cb';

  bool get isNimbostratus => code == 'Ns';

  bool get isRainCloud =>
      code == 'Cb' || code == 'Ns';

  bool get isConvectiveCloud =>
      code == 'Cb';

  bool get isHighCloud =>
      code == 'Ci' ||
      code == 'Cs' ||
      code == 'Cc';

  bool get isLowCloud =>
      code == 'Cu' ||
      code == 'Sc' ||
      code == 'St';
}

class CloudClassifierService {
  static const String modelPath =
      'assets/models/ccsn_cloud_classification_model.tflite';

  Interpreter? _interpreter;

  bool _initialized = false;

  static const List<String> _names = [
    'Cirrus',
    'Cirrostratus',
    'Cirrocumulus',
    'Altocumulus',
    'Altostratus',
    'Cumulus',
    'Cumulonimbus',
    'Nimbostratus',
    'Stratocumulus',
    'Stratus',
    'Contrail',
  ];

  static const List<String> _codes = [
    'Ci',
    'Cs',
    'Cc',
    'Ac',
    'As',
    'Cu',
    'Cb',
    'Ns',
    'Sc',
    'St',
    'Ct',
  ];

  Future<void> initialize() async {
    if (_initialized && _interpreter != null) {
      return;
    }

    try {
      _interpreter = await Interpreter.fromAsset(
        modelPath,
      );

      _interpreter!.allocateTensors();

      _initialized = true;

      final input =
          _interpreter!.getInputTensor(0);

      final output =
          _interpreter!.getOutputTensor(0);

      print('========================================');
      print('CLOUD AI: MODEL LOADED');
      print('CLOUD AI INPUT SHAPE: ${input.shape}');
      print('CLOUD AI INPUT TYPE: ${input.type}');
      print('CLOUD AI OUTPUT SHAPE: ${output.shape}');
      print('CLOUD AI OUTPUT TYPE: ${output.type}');
      print('========================================');
    } catch (e) {
      print('CLOUD AI INIT ERROR: $e');

      _interpreter = null;
      _initialized = false;
    }
  }

  Future<CloudClassificationResult?> classify(
    Uint8List imageBytes,
  ) async {
    try {
      await initialize();

      if (_interpreter == null) {
        return null;
      }

      final decoded =
          img.decodeImage(imageBytes);

      if (decoded == null) {
        print(
          'CLOUD AI: IMAGE DECODE FAILED',
        );

        return null;
      }

      final resized = img.copyResize(
        decoded,
        width: 224,
        height: 224,
        interpolation:
            img.Interpolation.linear,
      );

      final input = List.generate(
        1,
        (_) => List.generate(
          224,
          (y) => List.generate(
            224,
            (x) {
              final pixel =
                  resized.getPixel(
                x,
                y,
              );

              return [
                pixel.r / 255.0,
                pixel.g / 255.0,
                pixel.b / 255.0,
              ];
            },
          ),
        ),
      );

      final outputTensor =
          _interpreter!
              .getOutputTensor(0);

      final outputSize =
          outputTensor.shape.last;

      final output =
          List.generate(
        1,
        (_) => List<double>.filled(
          outputSize,
          0.0,
        ),
      );

      _interpreter!.run(
        input,
        output,
      );

      final List<double> scores =
          output[0]
              .map(
                (value) =>
                    (value as num)
                        .toDouble(),
              )
              .toList();

      if (scores.isEmpty) {
        return null;
      }

      int bestIndex = 0;
      double bestScore = scores[0];

      for (int i = 1;
          i < scores.length;
          i++) {
        if (scores[i] > bestScore) {
          bestScore = scores[i];
          bestIndex = i;
        }
      }

      if (bestIndex < 0 ||
          bestIndex >= _names.length) {
        print(
          'CLOUD AI: UNKNOWN CLASS $bestIndex',
        );

        return null;
      }

      double confidence;

      final bool looksLikeProbabilities =
          scores.every(
        (value) =>
            value >= 0.0 &&
            value <= 1.0,
      );

      if (looksLikeProbabilities) {
        confidence = bestScore;
      } else {
        confidence =
            _softmax(scores)[bestIndex];
      }

      final result =
          CloudClassificationResult(
        name: _names[bestIndex],
        code: _codes[bestIndex],
        confidence:
            confidence.clamp(
          0.0,
          1.0,
        ),
      );

      print('========================================');
      print('CLOUD AI RESULT');
      print('TYPE: ${result.name}');
      print('CODE: ${result.code}');
      print(
        'CONFIDENCE: '
        '${(result.confidence * 100).toStringAsFixed(1)}%',
      );
      print('========================================');

      return result;
    } catch (e) {
      print(
        'CLOUD AI CLASSIFICATION ERROR: $e',
      );

      return null;
    }
  }

  List<double> _softmax(
    List<double> values,
  ) {
    if (values.isEmpty) {
      return [];
    }

    final maxValue =
        values.reduce(
      (a, b) => a > b ? a : b,
    );

    final exponentials =
        values.map(
      (value) =>
          _exp(value - maxValue),
    );

    final sum =
        exponentials.fold<double>(
      0.0,
      (a, b) => a + b,
    );

    if (sum == 0) {
      return List<double>.filled(
        values.length,
        0.0,
      );
    }

    return exponentials
        .map(
          (value) => value / sum,
        )
        .toList();
  }

  double _exp(double value) {
    double result = 1.0;
    double term = 1.0;

    for (int i = 1;
        i <= 20;
        i++) {
      term *= value / i;
      result += term;
    }

    return result;
  }

  void dispose() {
    _interpreter?.close();
    _interpreter = null;
    _initialized = false;
  }
}
