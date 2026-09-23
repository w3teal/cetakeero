import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../layout/page_layout.dart';
import '../models/print_settings.dart';

/// A miniature rendering of a printed page for a single image, reflecting the
/// current [PrintSettings] so it looks exactly like the print result.
class PagePreview extends StatelessWidget {
  const PagePreview({
    super.key,
    required this.image,
    required this.settings,
    required this.width,
  });

  final ui.Image? image;
  final PrintSettings settings;

  /// Page width in logical pixels; height follows the paper aspect ratio.
  final double width;

  @override
  Widget build(BuildContext context) {
    final pageSize = pageSizeFor(settings);
    final height = width * pageSize.height / pageSize.width;
    return CustomPaint(
      size: Size(width, height),
      painter: _PagePreviewPainter(image: image, settings: settings),
    );
  }
}

class _PagePreviewPainter extends CustomPainter {
  const _PagePreviewPainter({required this.image, required this.settings});

  final ui.Image? image;
  final PrintSettings settings;

  @override
  void paint(Canvas canvas, Size size) {
    final pageSize = pageSizeFor(settings);
    final scaleX = size.width / pageSize.width;
    final scaleY = size.height / pageSize.height;

    final page = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawRect(page, Paint()..color = Colors.white);

    final marginPt = mmToPoints(settings.marginMm);
    final content = Rect.fromLTWH(
      marginPt * scaleX,
      marginPt * scaleY,
      math.max(0.0, (pageSize.width - 2 * marginPt)) * scaleX,
      math.max(0.0, (pageSize.height - 2 * marginPt)) * scaleY,
    );

    final decoded = image;
    if (decoded != null) {
      final rect = fitRect(
        content: content.size,
        image: Size(decoded.width.toDouble(), decoded.height.toDouble()),
        fit: settings.fit,
      ).shift(content.topLeft);

      canvas.save();
      canvas.clipRect(content);
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
      content,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Colors.black12,
    );
    canvas.drawRect(
      page,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Colors.black26,
    );
  }

  @override
  bool shouldRepaint(_PagePreviewPainter oldDelegate) =>
      oldDelegate.image != image || oldDelegate.settings != settings;
}