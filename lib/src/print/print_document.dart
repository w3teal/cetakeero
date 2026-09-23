import 'dart:math' as math;
import 'dart:ui' show Size;

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../layout/page_layout.dart';
import '../models/print_settings.dart';
import 'print_image.dart';

/// One page's worth of content: either a single image filling the page or a
/// grid of images tiled by [rows] x [cols].
sealed class PrintPageSource {
  const PrintPageSource();
}

/// The image is placed on the page (respecting [PrintSettings.fit]).
class PrintSingleSource extends PrintPageSource {
  const PrintSingleSource(this.image);

  final PrintImage image;
}

/// The images are tiled onto the page in [rows] x [cols] cells.
class PrintGridSource extends PrintPageSource {
  const PrintGridSource({
    required this.images,
    required this.rows,
    required this.cols,
    this.gapMm = 0,
  }) : assert(rows > 0 && cols > 0);

  final List<PrintImage> images;
  final int rows;
  final int cols;

  /// Space between cells in millimetres, matching the on-screen preview.
  final double gapMm;
}

/// Builds a multi-page PDF document, one page per [pages].
///
/// When [format] is provided (e.g. chosen by the user in the print dialog) it
/// overrides the page size derived from [settings]. Margins always come from
/// [settings], and cell layout matches the on-screen previews exactly.
pw.Document buildPrintDocument({
  required List<PrintPageSource> pages,
  required PrintSettings settings,
  PdfPageFormat? format,
}) {
  final document = pw.Document(title: 'cetakeero');
  final margin = mmToPoints(settings.marginMm);
  final pageFormat = format ??
      PdfPageFormat(
        mmToPoints(settings.widthMm),
        mmToPoints(settings.heightMm),
        marginAll: margin,
      );
  final content = Size(
    math.max(0.0, pageFormat.width - 2 * margin),
    math.max(0.0, pageFormat.height - 2 * margin),
  );

  for (final page in pages) {
    switch (page) {
      case PrintSingleSource(:final image):
        document.addPage(
          _singlePage(
            pageFormat: pageFormat,
            margin: margin,
            content: content,
            image: image,
            fit: settings.fit,
          ),
        );
      case PrintGridSource(:final images, :final rows, :final cols, :final gapMm):
        document.addPage(
          _gridPage(
            pageFormat: pageFormat,
            margin: margin,
            content: content,
            images: images,
            rows: rows,
            cols: cols,
            gapMm: gapMm,
            fit: settings.fit,
          ),
        );
    }
  }

  return document;
}

pw.Page _singlePage({
  required PdfPageFormat pageFormat,
  required double margin,
  required Size content,
  required PrintImage image,
  required ImageFit fit,
}) {
  final rect = fitRect(
    content: content,
    image: Size(image.width.toDouble(), image.height.toDouble()),
    fit: fit,
  );
  return pw.Page(
    pageFormat: pageFormat,
    margin: pw.EdgeInsets.zero,
    build: (_) => pw.Stack(
      children: [
        pw.Positioned(
          left: margin,
          top: margin,
          right: margin,
          bottom: margin,
          child: pw.ClipRect(
            child: pw.Stack(
              children: [
                pw.Positioned(
                  left: rect.left,
                  top: rect.top,
                  child: pw.Image(
                    pw.MemoryImage(image.bytes),
                    width: rect.width,
                    height: rect.height,
                    fit: pw.BoxFit.contain,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

pw.Page _gridPage({
  required PdfPageFormat pageFormat,
  required double margin,
  required Size content,
  required List<PrintImage> images,
  required int rows,
  required int cols,
  double gapMm = 0,
  required ImageFit fit,
}) {
  final cells = gridCellRects(
    content: content,
    rows: rows,
    cols: cols,
    gap: mmToPoints(gapMm),
  );
  final cover = fit == ImageFit.cover;
  return pw.Page(
    pageFormat: pageFormat,
    margin: pw.EdgeInsets.zero,
    build: (_) => pw.Stack(
      children: [
        pw.Positioned(
          left: margin,
          top: margin,
          right: margin,
          bottom: margin,
          child: pw.ClipRect(
            child: pw.Stack(
              children: [
                for (var i = 0; i < images.length && i < cells.length; i++)
                  () {
                    // Same math and fit as the on-screen grid preview. For
                    // cover the image fills its cell and is cropped by the
                    // cell's own box; for contain fitRect gives the exact
                    // laid-out rect.
                    final cell = cells[i];
                    final covers = cover;
                    final rect = fitRect(
                      content: cell.size,
                      image: Size(
                        images[i].width.toDouble(),
                        images[i].height.toDouble(),
                      ),
                      fit: fit,
                    );
                    final box = covers
                        ? cell
                        : rect.shift(cell.topLeft);
                    return pw.Positioned(
                      left: box.left,
                      top: box.top,
                      child: pw.Image(
                        pw.MemoryImage(images[i].bytes),
                        width: box.width,
                        height: box.height,
                        fit: covers ? pw.BoxFit.cover : pw.BoxFit.contain,
                      ),
                    );
                  }(),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}