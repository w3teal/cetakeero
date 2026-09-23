import 'dart:math' as math;

import 'selected_image.dart';

/// A print queue entry: either a single image, one per page, or a grid that
/// tiles several images onto a single page.
sealed class PrintEntry {
  const PrintEntry();

  /// The images held by this entry. Each image belongs to exactly one entry.
  List<SelectedImage> get images;
}

/// One page per image.
class ImageEntry extends PrintEntry {
  const ImageEntry(this.image);

  final SelectedImage image;

  @override
  List<SelectedImage> get images => [image];
}

/// Several images tiled onto a single page in [rows] x [cols] cells, with
/// [gapMm] millimetres of space between the cells.
class GridEntry extends PrintEntry {
  const GridEntry({
    required this.images,
    required this.rows,
    required this.cols,
    this.gapMm = 0,
  }) : assert(rows > 0 && cols > 0);

  @override
  final List<SelectedImage> images;
  final int rows;
  final int cols;

  /// Gap between cells in millimetres (prints and previews identically).
  final double gapMm;
}

/// A sensible default grid shape for [count] images (roughly square).
(int rows, int cols) defaultGridSize(int count) {
  if (count <= 0) return (1, 1);
  final cols = math.sqrt(count).ceil();
  final rows = (count / cols).ceil();
  return (rows, cols);
}