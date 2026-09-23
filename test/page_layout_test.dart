import 'dart:ui';

import 'package:cetakeero/src/layout/page_layout.dart';
import 'package:cetakeero/src/models/print_settings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('mmToPoints', () {
    test('converts millimeters to PDF points', () {
      expect(mmToPoints(25.4), closeTo(72.0, 1e-9));
      expect(mmToPoints(0), 0);
      expect(mmToPoints(210), closeTo(595.28, 0.01));
    });
  });

  group('pageSizeFor', () {
    test('A4 portrait has short width', () {
      const settings = PrintSettings(
        paperSize: PaperSize.a4,
        orientation: PageOrientation.portrait,
      );
      final size = pageSizeFor(settings);
      expect(size.width, closeTo(mmToPoints(210), 1e-9));
      expect(size.height, closeTo(mmToPoints(297), 1e-9));
    });

    test('A4 landscape swaps dimensions', () {
      const settings = PrintSettings(
        paperSize: PaperSize.a4,
        orientation: PageOrientation.landscape,
      );
      final size = pageSizeFor(settings);
      expect(size.width, closeTo(mmToPoints(297), 1e-9));
      expect(size.height, closeTo(mmToPoints(210), 1e-9));
    });

    test('A0 is the largest page', () {
      const settings = PrintSettings(paperSize: PaperSize.a0);
      final size = pageSizeFor(settings);
      expect(size.width, greaterThan(pageSizeFor(const PrintSettings()).width));
      expect(size.height,
          greaterThan(pageSizeFor(const PrintSettings()).height));
    });
  });

  group('contentRectFor', () {
    test('insets the page by the margin on all sides', () {
      const settings = PrintSettings(
        paperSize: PaperSize.a4,
        marginMm: 10,
      );
      final rect = contentRectFor(settings);
      expect(rect.left, closeTo(mmToPoints(10), 1e-9));
      expect(rect.top, closeTo(mmToPoints(10), 1e-9));
      expect(rect.width, closeTo(mmToPoints(190), 1e-9));
      expect(rect.height, closeTo(mmToPoints(277), 1e-9));
    });
  });

  group('fitRect', () {
    test('returns zero rect for degenerate inputs', () {
      expect(
        fitRect(
          content: const Size(100, 100),
          image: const Size(0, 0),
          fit: ImageFit.contain,
        ),
        Rect.zero,
      );
      expect(
        fitRect(
          content: const Size(0, 100),
          image: const Size(10, 10),
          fit: ImageFit.cover,
        ),
        Rect.zero,
      );
    });

    group('contain', () {
      test('fits a landscape image inside a portrait area, centered', () {
        final rect = fitRect(
          content: const Size(100, 200),
          image: const Size(2000, 1000),
          fit: ImageFit.contain,
        );
        expect(rect.size.width, closeTo(100, 1e-9));
        expect(rect.size.height, closeTo(50, 1e-9));
        expect(rect.left, closeTo(0, 1e-9));
        expect(rect.top, closeTo(75, 1e-9));
      });

      test('keeps a portrait image fully visible', () {
        final rect = fitRect(
          content: const Size(100, 200),
          image: const Size(1000, 2000),
          fit: ImageFit.contain,
        );
        expect(rect.size.width, closeTo(100, 1e-9));
        expect(rect.size.height, closeTo(200, 1e-9));
        expect(rect.top, closeTo(0, 1e-9));
        expect(rect.left, closeTo(0, 1e-9));
      });

      test('never exceeds the content bounds', () {
        final content = const Size(300, 150);
        for (final image in [
          const Size(10, 10),
          const Size(400, 900),
          const Size(1, 600),
        ]) {
          final rect = fitRect(
            content: content,
            image: image,
            fit: ImageFit.contain,
          );
          expect(rect.width, lessThanOrEqualTo(content.width));
          expect(rect.height, lessThanOrEqualTo(content.height));
          expect(rect.left, greaterThanOrEqualTo(0));
          expect(rect.top, greaterThanOrEqualTo(0));
        }
      });
    });

    group('cover', () {
      test('fills the tall area, cropping the wide image edges', () {
        final rect = fitRect(
          content: const Size(100, 200),
          image: const Size(2000, 1000),
          fit: ImageFit.cover,
        );
        expect(rect.size.height, closeTo(200, 1e-9));
        expect(rect.size.width, closeTo(400, 1e-9));
        expect(rect.left, closeTo(-150, 1e-9));
        expect(rect.top, closeTo(0, 1e-9));
      });

      test('fills the wide area, cropping the tall image edges', () {
        final rect = fitRect(
          content: const Size(200, 100),
          image: const Size(1000, 2000),
          fit: ImageFit.cover,
        );
        expect(rect.size.width, closeTo(200, 1e-9));
        expect(rect.size.height, closeTo(400, 1e-9));
        expect(rect.left, closeTo(0, 1e-9));
        expect(rect.top, closeTo(-150, 1e-9));
      });

      test('always covers the content bounds', () {
        final content = const Size(300, 150);
        for (final image in [
          const Size(10, 10),
          const Size(400, 900),
          const Size(1, 600),
        ]) {
          final rect = fitRect(
            content: content,
            image: image,
            fit: ImageFit.cover,
          );
          expect(rect.width, greaterThanOrEqualTo(content.width));
          expect(rect.height, greaterThanOrEqualTo(content.height));
        }
      });

      test('matches contain for identical aspect ratios', () {
        const content = Size(200, 100);
        const image = Size(1000, 500);
        final contain = fitRect(
          content: content,
          image: image,
          fit: ImageFit.contain,
        );
        final cover = fitRect(
          content: content,
          image: image,
          fit: ImageFit.cover,
        );
        expect(contain, cover);
      });
    });
  });

  group('gridCellRects', () {
    test('splits the content into rows x cols cells, row-major', () {
      const content = Size(200, 100);
      final cells = gridCellRects(content: content, rows: 2, cols: 2);
      expect(cells, hasLength(4));
      expect(cells[0], const Rect.fromLTWH(0, 0, 100, 50));
      expect(cells[1], const Rect.fromLTWH(100, 0, 100, 50));
      expect(cells[2], const Rect.fromLTWH(0, 50, 100, 50));
      expect(cells[3], const Rect.fromLTWH(100, 50, 100, 50));
    });

    test('handles non-square grids', () {
      const content = Size(210, 297);
      final cells = gridCellRects(content: content, rows: 3, cols: 2);
      expect(cells, hasLength(6));
      expect(cells.first.width, closeTo(105, 1e-9));
      expect(cells.first.height, closeTo(99, 1e-9));
      expect(cells[5].bottom, closeTo(297, 1e-9));
      expect(cells[5].right, closeTo(210, 1e-9));
    });

    test('covers single-row and single-column grids', () {
      expect(
        gridCellRects(content: const Size(100, 50), rows: 1, cols: 3),
        hasLength(3),
      );
      expect(gridCellRects(content: const Size(100, 50), rows: 1, cols: 3)[2],
          const Rect.fromLTWH(200 / 3, 0, 100 / 3, 50));
      expect(
        gridCellRects(content: const Size(100, 50), rows: 3, cols: 1),
        hasLength(3),
      );
    });

    test('returns no cells for invalid dimensions', () {
      expect(gridCellRects(content: const Size(10, 10), rows: 0, cols: 2),
          isEmpty);
      expect(gridCellRects(content: const Size(10, 10), rows: 2, cols: -1),
          isEmpty);
    });

    test('subtracts the gap from cell size and spaces the cells', () {
      const content = Size(100, 100);
      final cells = gridCellRects(content: content, rows: 2, cols: 2, gap: 4);
      expect(cells, hasLength(4));
      // (100 - 4) / 2 per axis.
      expect(cells[0].width, closeTo(48, 1e-9));
      expect(cells[0].height, closeTo(48, 1e-9));
      // Row-major: next cell shifted by width + gap.
      expect(cells[1].left, closeTo(52, 1e-9));
      expect(cells[1].top, closeTo(0, 1e-9));
      expect(cells[2].left, closeTo(0, 1e-9));
      expect(cells[2].top, closeTo(52, 1e-9));
      expect(cells[3].right, closeTo(100, 1e-9));
      expect(cells[3].bottom, closeTo(100, 1e-9));
    });

    test('gap smaller than content keeps cells non-negative', () {
      final cells = gridCellRects(
        content: const Size(10, 10),
        rows: 3,
        cols: 3,
        gap: 4,
      );
      for (final cell in cells) {
        expect(cell.width, greaterThanOrEqualTo(0));
        expect(cell.height, greaterThanOrEqualTo(0));
      }
    });
  });
}