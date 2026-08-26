import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

class CloudClassificationResult {
  final String label;
  final String shortLabel;
  final double confidence;

  const CloudClassificationResult({
    required this.label,
    required this.shortLabel,
    required this.confidence,
  });

  bool get isConvective {
    return shortLabel == 'Cb';
  }

  bool get isRainCloud {
    return shortLabel == 'Cb' ||
        shortLabel == 'Ns';
  }

  bool get isHighCloud {
    return shortLabel == 'Ci' ||
        shortLabel == 'Cs' ||
        shortLabel == 'Cc';
  }

  bool get isLowCloud {
    return shortLabel == 'Cu' ||
        shortLabel == 'Sc' ||
        shortLabel == 'St';
  }
}

class CloudClassifierService {
  static const String _modelPath =
      'assets/models/cloud_classifier.tflite';

  Interpreter? _interpreter;

  static const List<String> _labels = [
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

  static const List<String> _shortLabels = [
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

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    try {
      _interpreter =
          await Interpreter.fromAsset(
        _modelPath,
      );

      _interpreter!.allocateTensors();

      _initialized = true;

      print(
        'CLOUD AI: model loaded successfully',
      );

      print(
        'CLOUD AI INPUT: '
        '${_interpreter!.getInputTensor(0).shape}',
      );

      print(
        'CLOUD AI OUTPUT: '
        '${_interpreter!.getOutputTensor(0).shape}',
      );
    } catch (e) {
      print(
        'CLOUD AI INIT ERROR: $e',
      );

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
          'CLOUD AI: image decode failed',
        );

        return null;
      }

      // Model očakáva 224 x 224 RGB.
      final resized =
          img.copyResize(
        decoded,
        width: 224,
        height: 224,
        interpolation:
            img.Interpolation.linear,
      );

      // ----------------------------------------------------------
      // Vstupný tensor:
      //
      // [1, 224, 224, 3]
      //
      // RGB float32 v rozsahu 0.0 - 1.0
      // ----------------------------------------------------------

      final input =
          List.generate(
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

      final outputShape =
          _interpreter!
              .getOutputTensor(0)
              .shape;

      final int outputSize =
          outputShape.last;

      final output =
          List.generate(
        1,
        (_) => List.filled(
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

      double bestScore =
          scores[0];

      for (int i = 1;
          i < scores.length;
          i++) {
        if (scores[i] >
            bestScore) {
          bestScore =
              scores[i];

          bestIndex = i;
        }
      }

      if (bestIndex >=
          _labels.length) {
        print(
          'CLOUD AI: unknown class index $bestIndex',
        );

        return null;
      }

      final result =
          CloudClassificationResult(
        label: _labels[bestIndex],
        shortLabel:
            _shortLabels[bestIndex],
        confidence:
            bestScore.clamp(
              0.0,
              1.0,
            ),
      );

      print(
        'CLOUD AI RESULT: '
        '${result.label} '
        '(${result.shortLabel}) '
        '${(result.confidence * 100).toStringAsFixed(1)}%',
      );

      return result;
    } catch (e) {
      print(
        'CLOUD AI CLASSIFICATION ERROR: $e',
      );

      return null;
    }
  }

  void dispose() {
    _interpreter?.close();
    _interpreter = null;
    _initialized = false;
  }
}
