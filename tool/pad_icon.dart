import 'dart:io';
import 'dart:math' as math;
import 'package:image/image.dart' as img;

/// Generates a padded adaptive icon foreground from the source image.
/// This helps prevent cropping by Android's adaptive icon mask.
///
/// Input:  assets/icons/hrm-icon.jpg
/// Output: assets/icons/hrm-icon-adaptive.png
void main() async {
  const inputPath = 'assets/icons/hrm-icon.jpg';
  const outputPath = 'assets/icons/hrm-icon-adaptive.png';

  if (!File(inputPath).existsSync()) {
    stderr.writeln('Input icon not found at: $inputPath');
    exit(1);
  }

  // Read source image
  final bytes = await File(inputPath).readAsBytes();
  final src = img.decodeImage(bytes);
  if (src == null) {
    stderr.writeln('Failed to decode input image');
    exit(2);
  }

  // Create 1024x1024 canvas (recommended adaptive icon size)
  const size = 1024;
  // Keep a safe padding so the mask won't crop; 20% padding is a good default
  const paddingRatio = 0.20; // 20% on each side
  final safeSize = (size * (1.0 - paddingRatio * 2)).toInt();

  // Fit the source image inside safe area preserving aspect ratio
  final scale = math.min(safeSize / src.width, safeSize / src.height);
  final targetW = (src.width * scale).round();
  final targetH = (src.height * scale).round();
  final fitted = img.copyResize(
    src,
    width: targetW,
    height: targetH,
    interpolation: img.Interpolation.cubic,
  );

  // Transparent background so we can use a separate background color via adaptive_icon_background
  final canvas = img.Image(width: size, height: size);
  img.fill(canvas, color: img.ColorRgba8(0, 0, 0, 0));

  // Center the fitted image
  final dx = ((size - fitted.width) / 2).round();
  final dy = ((size - fitted.height) / 2).round();
  img.compositeImage(canvas, fitted, dstX: dx, dstY: dy);

  // Save as PNG to preserve transparency
  final outBytes = img.encodePng(canvas);
  await File(outputPath).writeAsBytes(outBytes);
  stdout.writeln('Generated padded adaptive icon at $outputPath');
}
