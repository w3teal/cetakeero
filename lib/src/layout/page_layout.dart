import 'dart:math' as math;

import 'dart:ui';

import '../models/print_settings.dart';

/// One PDF point equals 1/72 inch.
const double pointsPerMillimeter = 72.0 / 25.4;

double mmToPoints(double millimeters) => millimeters * pointsPerMillimeter;

/// Oriented sheet size in PDF points.
Size pageSizeFor(PrintSettings settings) =>
    Size(mmToPoints(settings.widthMm), mmToPoints(settings.heightMm));

/// Printable area inside the margins, in PDF points.
Rect contentRectFor(PrintSettings settings) {
  final size = pageSizeFor(settings);
  final margin = mmToPoints(settings.marginMm);
  final width = math.max(0.0, size.width - 2 * margin);
  final height = math.max(0.0, size.height - 2 * margin);
  return Rect.fromLTWH(margin, margin, width, height);
}

/// Computes the placement of [image] inside [content].
///
/// The returned [Rect] uses the coordinate space of [content] (its top-left
/// corner is `(0, 0)`). With [ImageFit.contain] the whole image stays visible;
/// with [ImageFit.cover] the image fills the area and may extend past the
/// bounds (to be clipped by the caller).
Rect fitRect({
  required Size content,
  required Size image,
  required ImageFit fit,
}) {
  if (content.width <= 0 ||
      content.height <= 0 ||
      image.width <= 0 ||
      image.height <= 0) {
    return Rect.zero;
  }

  final scale = fit == ImageFit.contain
      ? math.min(content.width / image.width, content.height / image.height)
      : math.max(content.width / image.width, content.height / image.height);
  final width = image.width * scale;
  final height = image.height * scale;
  return Rect.fromLTWH(
    (content.width - width) / 2,
    (content.height - height) / 2,
    width,
    height,
  );
}

/// Splits [content] into a [rows] x [cols] grid of cells, row-major.
///
/// The returned [Rect]s are in the coordinate space of [content] (its
/// top-left corner is `(0, 0)`). There are always `rows * cols` of them.
/// [gap] (in the same unit as [content]) leaves space between the cells.
List<Rect> gridCellRects({
  required Size content,
  required int rows,
  required int cols,
  double gap = 0,
}) {
  if (rows <= 0 || cols <= 0) return const [];
  final cellWidth =
      math.max(0.0, (content.width - gap * (cols - 1)) / cols);
  final cellHeight =
      math.max(0.0, (content.height - gap * (rows - 1)) / rows);
  return [
    for (var r = 0; r < rows; r++)
      for (var c = 0; c < cols; c++)
        Rect.fromLTWH(
          c * (cellWidth + gap),
          r * (cellHeight + gap),
          cellWidth,
          cellHeight,
        ),
  ];
}