import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// A square, cover-cropped image thumbnail with an index badge and an
/// optional remove button.
class ImageThumb extends StatelessWidget {
  const ImageThumb({
    super.key,
    required this.image,
    required this.label,
    required this.size,
    this.highlighted = false,
    this.onRemove,
  });

  final ui.Image image;
  final String label;
  final double size;
  final bool highlighted;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      foregroundDecoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: highlighted
            ? Border.all(color: colorScheme.primary, width: 3)
            : Border.all(color: colorScheme.outlineVariant),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(
            painter: _CoverThumbPainter(image),
            child: const SizedBox.expand(),
          ),
          Positioned(
            top: 6,
            left: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: colorScheme.inverseSurface.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colorScheme.onInverseSurface,
                ),
              ),
            ),
          ),
          if (onRemove != null)
            Positioned(
              top: 4,
              right: 4,
              child: IconButton.filledTonal(
                tooltip: 'Remove',
                iconSize: 16,
                visualDensity: VisualDensity.compact,
                onPressed: onRemove,
                icon: const Icon(Icons.close),
              ),
            ),
        ],
      ),
    );
  }
}

class _CoverThumbPainter extends CustomPainter {
  const _CoverThumbPainter(this.image);

  final ui.Image image;

  @override
  void paint(Canvas canvas, Size size) {
    final imageAspect = image.width / image.height;
    final boxAspect = size.width / size.height;
    late final Rect dst;
    if (imageAspect >= boxAspect) {
      final width = size.height * imageAspect;
      dst = Rect.fromLTWH(
        (size.width - width) / 2,
        0,
        width,
        size.height,
      );
    } else {
      final height = size.width / imageAspect;
      dst = Rect.fromLTWH(
        0,
        (size.height - height) / 2,
        size.width,
        height,
      );
    }
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(
        0,
        0,
        image.width.toDouble(),
        image.height.toDouble(),
      ),
      dst,
      Paint()..filterQuality = FilterQuality.medium,
    );
  }

  @override
  bool shouldRepaint(_CoverThumbPainter oldDelegate) =>
      oldDelegate.image != image;
}