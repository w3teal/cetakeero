import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../layout/page_layout.dart';
import '../models/print_settings.dart';

/// A miniature page showing several images tiled onto one page, mirroring the
/// print result exactly.
class GridPreview extends StatelessWidget {
  const GridPreview({
    super.key,
    required this.images,
    required this.rows,
    required this.cols,
    required this.settings,
    required this.width,
    this.gapMm = 0,
    this.cellOverlayBuilder,
  });

  /// Cell images in row-major order; more cells than images stay empty.
  final List<ui.Image?> images;
  final int rows;
  final int cols;
  final PrintSettings settings;

  /// Page width in logical pixels; height follows the paper aspect ratio.
  final double width;

  /// Space between cells in millimetres, matching the print layout.
  final double gapMm;

  /// Optional overlay widget placed over each cell, positioned at that cell's
  /// rect inside the page.
  final Widget Function(int cellIndex, Rect cell)? cellOverlayBuilder;

  /// Page size in logical pixels for [settings] and [width].
  static Size sizeFor(PrintSettings settings, double width) {
    final size = pageSizeFor(settings);
    return Size(width, width * size.height / size.width);
  }

  /// Content area (inside the margins) in logical pixels.
  static Rect contentFor(PrintSettings settings, double width) {
    final size = pageSizeFor(settings);
    final margin = mmToPoints(settings.marginMm);
    final scale = width / size.width;
    return Rect.fromLTWH(
      margin * scale,
      margin * scale,
      math.max(0.0, size.width - 2 * margin) * scale,
      math.max(0.0, size.height - 2 * margin) * scale,
    );
  }

  /// Cell rects in logical pixels for [settings] and [width].
  static List<Rect> cellRectsFor(
    PrintSettings settings,
    double width, {
    required int rows,
    required int cols,
    double gapMm = 0,
  }) {
    final size = pageSizeFor(settings);
    final margin = mmToPoints(settings.marginMm);
    final contentMm = Size(
      math.max(0.0, size.width - 2 * margin),
      math.max(0.0, size.height - 2 * margin),
    );
    final content = contentFor(settings, width);
    final cells = gridCellRects(
      content: contentMm,
      rows: rows,
      cols: cols,
      gap: gapMm,
    );
    return [
      for (final cell in cells)
        Rect.fromLTWH(
          content.left + cell.left * content.width / contentMm.width,
          content.top + cell.top * content.height / contentMm.height,
          cell.width * content.width / contentMm.width,
          cell.height * content.height / contentMm.height,
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final size = sizeFor(settings, width);
    final cells = cellRectsFor(
      settings,
      width,
      rows: rows,
      cols: cols,
      gapMm: gapMm,
    );
    return CustomPaint(
      size: size,
      painter: _GridPreviewPainter(
        images: images,
        cells: cells,
        settings: settings,
        width: width,
        gapMm: gapMm,
      ),
      child: SizedBox(
        width: size.width,
        height: size.height,
        child: Stack(
          children: [
            if (cellOverlayBuilder != null)
              for (var i = 0; i < cells.length; i++)
                Positioned.fromRect(
                  rect: cells[i],
                  child: cellOverlayBuilder!(i, cells[i]),
                ),
          ],
        ),
      ),
    );
  }
}

class _GridPreviewPainter extends CustomPainter {
  const _GridPreviewPainter({
    required this.images,
    required this.cells,
    required this.settings,
    required this.width,
    required this.gapMm,
  });

  final List<ui.Image?> images;
  final List<Rect> cells;
  final PrintSettings settings;
  final double width;
  final double gapMm;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = Colors.white,
    );
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Colors.black26,
    );

    final divider = Paint()
      ..color = Colors.black26
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(0.5, size.width * 0.002);

    for (var i = 0; i < cells.length; i++) {
      final cell = cells[i];
      final image = i < images.length ? images[i] : null;
      final decoded = image;
      if (decoded != null) {
        final rect = fitRect(
          content: cell.size,
          image: Size(
            decoded.width.toDouble(),
            decoded.height.toDouble(),
          ),
          fit: settings.fit,
        ).shift(cell.topLeft);

        canvas.save();
        canvas.clipRect(cell);
        canvas.drawImageRect(
          decoded,
          Rect.fromLTWH(
            0,
            0,
            decoded.width.toDouble(),
            decoded.height.toDouble(),
          ),
          rect,
          Paint()..filterQuality = FilterQuality.medium,
        );
        canvas.restore();
      }
      canvas.drawRect(
        cell,
        divider,
      );
    }
  }

  @override
  bool shouldRepaint(_GridPreviewPainter oldDelegate) =>
      oldDelegate.images != images ||
      oldDelegate.settings != settings ||
      oldDelegate.width != width ||
      oldDelegate.gapMm != gapMm;
}