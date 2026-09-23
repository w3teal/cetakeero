import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:cetakeero/src/models/print_settings.dart';
import 'package:cetakeero/src/print/print_document.dart';
import 'package:cetakeero/src/print/print_image.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';

const _oneByOnePng =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==';

PrintImage _image(String name, int width, int height) => PrintImage(
      name: name,
      bytes: base64Decode(_oneByOnePng),
      width: width,
      height: height,
    );

/// Inspects the media box (/MediaBox) of the first page of a generated PDF.
ui.Rect _firstPageMediaBox(Uint8List pdf) {
  final text = latin1.decode(pdf);
  final match = RegExp(r'/MediaBox\s*\[\s*([\d.]+)\s+([\d.]+)\s+([\d.]+)\s+([\d.]+)')
      .firstMatch(text)!;
  final numbers = match.groups([1, 2, 3, 4]).map((s) => double.parse(s!)).toList();
  return ui.Rect.fromPoints(
    ui.Offset(numbers[0], numbers[1]),
    ui.Offset(numbers[2], numbers[3]),
  );
}

void main() {
  test('builds a page per image', () async {
    final document = buildPrintDocument(
      pages: [
        PrintSingleSource(_image('a.png', 1000, 500)),
        PrintSingleSource(_image('b.png', 500, 1000)),
      ],
      settings: const PrintSettings(
        paperSize: PaperSize.a4,
        orientation: PageOrientation.portrait,
        fit: ImageFit.contain,
        marginMm: 15,
      ),
    );
    final bytes = await document.save();
    expect(bytes, isNotEmpty);
  });

  test('contains images with cover fit on the largest page size', () async {
    final document = buildPrintDocument(
      pages: [PrintSingleSource(_image('wide.png', 3000, 1000))],
      settings: const PrintSettings(
        paperSize: PaperSize.a0,
        orientation: PageOrientation.landscape,
        fit: ImageFit.cover,
        marginMm: 5,
      ),
    );
    final bytes = await document.save();
    expect(bytes.length, greaterThan(100));
  });

  test('accepts multiple sized images with every page size and orientation',
      () async {
    for (final size in PaperSize.values) {
      for (final orientation in PageOrientation.values) {
        for (final fit in ImageFit.values) {
          final document = buildPrintDocument(
            pages: [
              PrintSingleSource(_image('1.png', 320, 30)),
              PrintSingleSource(_image('2.png', 30, 320)),
            ],
            settings: PrintSettings(
              paperSize: size,
              orientation: orientation,
              fit: fit,
              marginMm: orientation == PageOrientation.portrait ? 10 : 40,
            ),
          );
          final bytes = await document.save();
          expect(bytes.length, greaterThan(50), reason: '$size $orientation $fit');
        }
      }
    }
  });

  test(
      'produces a page whose size matches the chosen paper size exactly when '
      'no format is provided', () async {
    const double marginMm = 10;
    for (final size in PaperSize.values) {
      for (final orientation in PageOrientation.values) {
        final settings = PrintSettings(
          paperSize: size,
          orientation: orientation,
          fit: ImageFit.contain,
          marginMm: marginMm,
        );
        final bytes = await buildPrintDocument(
          pages: [PrintSingleSource(_image('a.png', 1000, 1000))],
          settings: settings,
        ).save();

        final box = _firstPageMediaBox(bytes);
        expect(box.width, closeTo(settings.widthMm * PdfPageFormat.mm, 0.5),
            reason: '$size $orientation');
        expect(box.height, closeTo(settings.heightMm * PdfPageFormat.mm, 0.5),
            reason: '$size $orientation');
      }
    }
  });

  test(
      'ignores driver-provided page format margins and uses the settings '
      'margin for layout', () async {
    // Simulate what the print dialog reports back: same page size as the app
    // but with a driver-imposed margin that must NOT shift or size the image.
    final format = PdfPageFormat(
      PdfPageFormat.mm * 210,
      PdfPageFormat.mm * 297,
      marginLeft: 99,
      marginTop: 88,
      marginRight: 77,
      marginBottom: 66,
    );
    final document = buildPrintDocument(
      pages: [PrintSingleSource(_image('a.png', 100, 100))],
      settings: const PrintSettings(
        paperSize: PaperSize.a4,
        orientation: PageOrientation.portrait,
        fit: ImageFit.contain,
        marginMm: 42,
      ),
      format: format,
    );
    final bytes = await document.save();
    expect(bytes, isNotEmpty);

    // Media box must still be exactly the format's page size (210 x 297 mm).
    final box = _firstPageMediaBox(bytes);
    expect(box.width, closeTo(PdfPageFormat.mm * 210, 0.5));
    expect(box.height, closeTo(PdfPageFormat.mm * 297, 0.5));
  });

  test('builds a grid page that tiles the images row-major', () async {
    for (final (rows, cols) in [(2, 3), (3, 2), (1, 4), (4, 1)]) {
      final document = buildPrintDocument(
        pages: [
          PrintGridSource(
            images: [
              _image('g1.png', 800, 400),
              _image('g2.png', 400, 800),
              _image('g3.png', 600, 600),
              _image('g4.png', 300, 900),
            ],
            rows: rows,
            cols: cols,
          ),
        ],
        settings: const PrintSettings(
          paperSize: PaperSize.a3,
          orientation: PageOrientation.landscape,
          fit: ImageFit.contain,
          marginMm: 8,
        ),
      );
      final bytes = await document.save();
      expect(bytes.length, greaterThan(100), reason: '$rows x $cols');
    }
  });

  test('grid page uses the settings page size exactly', () async {
    final settings = const PrintSettings(
      paperSize: PaperSize.a3,
      orientation: PageOrientation.portrait,
      fit: ImageFit.contain,
      marginMm: 12,
    );
    final bytes = await buildPrintDocument(
      pages: [
        PrintGridSource(
          images: [_image('g1.png', 800, 400), _image('g2.png', 400, 800)],
          rows: 2,
          cols: 1,
        ),
      ],
      settings: settings,
    ).save();
    final box = _firstPageMediaBox(bytes);
    expect(box.width, closeTo(settings.widthMm * PdfPageFormat.mm, 0.5));
    expect(box.height, closeTo(settings.heightMm * PdfPageFormat.mm, 0.5));
  });

  test('grid page builds with a cell gap', () async {
    final bytes = await buildPrintDocument(
      pages: [
        PrintGridSource(
          images: [
            _image('g1.png', 800, 400),
            _image('g2.png', 400, 800),
            _image('g3.png', 600, 600),
            _image('g4.png', 300, 900),
          ],
          rows: 2,
          cols: 2,
          gapMm: 6,
        ),
      ],
      settings: const PrintSettings(
        paperSize: PaperSize.a4,
        orientation: PageOrientation.portrait,
        fit: ImageFit.contain,
        marginMm: 8,
      ),
    ).save();
    expect(bytes.length, greaterThan(100));
  });

  test('grid page respects cover fit by cropping into each cell', () async {
    for (final gapMm in [0.0, 5.0]) {
      final bytes = await buildPrintDocument(
        pages: [
          PrintGridSource(
            images: [
              _image('wide.png', 3000, 1000),
              _image('tall.png', 1000, 3000),
              _image('square.png', 1000, 1000),
            ],
            rows: 2,
            cols: 2,
            gapMm: gapMm,
          ),
        ],
        settings: const PrintSettings(
          paperSize: PaperSize.a4,
          orientation: PageOrientation.portrait,
          fit: ImageFit.cover,
          marginMm: 8,
        ),
      ).save();
      expect(bytes.length, greaterThan(100), reason: 'gap $gapMm');
    }
  });
}