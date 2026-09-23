import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:cetakeero/src/models/print_settings.dart';
import 'package:cetakeero/src/widgets/grid_preview.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _oneByOnePng =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==';

Future<ui.Image> _decode() async {
  final completer = Completer<ui.Image>();
  ui.decodeImageFromList(base64Decode(_oneByOnePng), completer.complete);
  return completer.future;
}

void main() {
  testWidgets('renders a grid preview for any rows/cols combination',
      (tester) async {
    final image = await tester.runAsync(_decode);
    addTearDown(image!.dispose);

    for (var rows = 1; rows <= 4; rows++) {
      for (var cols = 1; cols <= 4; cols++) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: GridPreview(
                  images: [image, image, image],
                  rows: rows,
                  cols: cols,
                  settings: const PrintSettings(
                    paperSize: PaperSize.a4,
                    orientation: PageOrientation.portrait,
                    marginMm: 10,
                  ),
                  width: 120,
                ),
              ),
            ),
          ),
        );
        expect(tester.takeException(), isNull, reason: '$rows x $cols');
      }
    }
  });

  testWidgets('lays out the content area inside the margins', (tester) async {
    const width = 120.0;
    final size = GridPreview.sizeFor(
      const PrintSettings(paperSize: PaperSize.a4),
      width,
    );
    final content = GridPreview.contentFor(
      const PrintSettings(
        paperSize: PaperSize.a4,
        marginMm: 10,
      ),
      width,
    );

    // A4 portrait: taller than wide; margin 10 mm on each side scales down.
    expect(size.height, greaterThan(size.width));
    final marginPx = size.width * 10 * 72 / 25.4 / (210 * 72 / 25.4);
    expect(content.left, closeTo(marginPx, 1e-6));
    expect(content.top, closeTo(marginPx, 1e-6));
    expect(content.right, closeTo(size.width - marginPx, 1e-6));
  });

  testWidgets('cell rects tile the content area row-major', (tester) async {
    const width = 120.0;
    const settings = PrintSettings(
      paperSize: PaperSize.a4,
      orientation: PageOrientation.portrait,
      marginMm: 10,
    );
    final cells = GridPreview.cellRectsFor(
      settings,
      width,
      rows: 2,
      cols: 3,
    );
    expect(cells, hasLength(6));

    final content = GridPreview.contentFor(settings, width);
    final cellW = content.width / 3;
    final cellH = content.height / 2;

    expect(cells[0].left, closeTo(content.left, 1e-6));
    expect(cells[0].top, closeTo(content.top, 1e-6));
    expect(cells[0].width, closeTo(cellW, 1e-6));
    expect(cells[0].height, closeTo(cellH, 1e-6));
    expect(cells[3].top, closeTo(content.top + cellH, 1e-6));
    expect(cells[5].right, closeTo(content.right, 1e-6));
    expect(cells[5].bottom, closeTo(content.bottom, 1e-6));
  });

  testWidgets('a non-zero gap shrinks cells and separates them',
      (tester) async {
    const width = 120.0;
    const settings = PrintSettings(
      paperSize: PaperSize.a4,
      orientation: PageOrientation.portrait,
      marginMm: 10,
    );
    final gapped = GridPreview.cellRectsFor(
      settings,
      width,
      rows: 2,
      cols: 2,
      gapMm: 6,
    );
    final tight = GridPreview.cellRectsFor(
      settings,
      width,
      rows: 2,
      cols: 2,
    );
    expect(gapped[0].width, lessThan(tight[0].width));
    expect(gapped[0].height, lessThan(tight[0].height));
    // Cell 1 is pushed right by gap; row 2 starts further down.
    expect(gapped[1].left, greaterThan(gapped[0].right));
    expect(gapped[2].top, greaterThan(gapped[0].bottom));
    // Total footprint unchanged.
    expect(gapped[3].right, closeTo(tight[3].right, 1e-6));
    expect(gapped[3].bottom, closeTo(tight[3].bottom, 1e-6));
  });

  testWidgets('places the cell overlays over each cell', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: GridPreview(
              images: const [],
              rows: 2,
              cols: 2,
              settings: const PrintSettings(paperSize: PaperSize.a4),
              width: 120,
              cellOverlayBuilder: (index, cell) =>
                  ColoredBox(color: Colors.red),
            ),
          ),
        ),
      ),
    );
    expect(
      find.descendant(
        of: find.byType(GridPreview),
        matching: find.byWidgetPredicate((widget) => widget is ColoredBox),
      ),
      findsNWidgets(4),
    );
  });
}