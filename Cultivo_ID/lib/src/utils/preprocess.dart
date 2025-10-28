import 'dart:math' as math;

import 'package:image/image.dart' as img;

List<List<List<double>>> preprocessTo112Rgb(img.Image image) {
  final img.Image rgb = img.copyResize(
    img.copyRotate(image, angle: 0),
    width: 112,
    height: 112,
    interpolation: img.Interpolation.average,
  );

  final List<List<List<double>>> result = List.generate(
    112,
    (_) => List.generate(112, (_) => List<double>.filled(3, 0)),
  );

  final bytes = rgb.getBytes();
  final int pixels = 112 * 112;
  final int step = (bytes.length ~/ pixels);
  int i = 0;
  for (int y = 0; y < 112; y++) {
    for (int x = 0; x < 112; x++) {
      final int r = bytes[i++];
      final int g = bytes[i++];
      final int b = bytes[i++];
      if (step == 4) {
        i++;
      }
      // Normalización cambiada a 0.0 - 1.0
      result[y][x][0] = r / 255.0;
      result[y][x][1] = g / 255.0;
      result[y][x][2] = b / 255.0;
    }
  }
  return result;
}