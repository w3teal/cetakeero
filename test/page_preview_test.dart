import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:cetakeero/src/models/print_settings.dart';
import 'package:cetakeero/src/widgets/page_preview.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

const _oneByOnePng =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==';

Future<ui.Image> _decode() async {
  final completer = Completer<ui.Image>();
  ui.decodeImageFromList(base64Decode(_oneByOnePng), completer.complete);
  return completer.future;
}

void main() {
  testWidgets('renderes a page preview for every setting combination',
      (tester) async {
    final image = await tester.runAsync(_decode);
    addTearDown(image!.dispose);

    for (final size in PaperSize.values) {
      for (final orientation in PageOrientation.values) {
        for (final fit in ImageFit.values) {
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: Center(
                  child: PagePreview(
                    image: image,
                    width: 120,
                    settings: PrintSettings(
                      paperSize: size,
                      orientation: orientation,
                      fit: fit,
                      marginMm: orientation == PageOrientation.portrait ? 10 : 45,
                    ),
                  ),
                ),
              ),
            ),
          );
          expect(tester.takeException(), isNull, reason: '$size $orientation $fit');
        }
      }
    }
  });

  testWidgets('page height follows the paper orientation aspect ratio',
      (tester) async {
    const portrait = PrintSettings(
      paperSize: PaperSize.a4,
      orientation: PageOrientation.portrait,
      marginMm: 10,
    );
    const landscape = PrintSettings(
      paperSize: PaperSize.a4,
      orientation: PageOrientation.landscape,
      marginMm: 10,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              PagePreview(width: 120, settings: portrait, image: null),
              PagePreview(width: 120, settings: landscape, image: null),
            ],
          ),
        ),
      ),
    );

    final portraitSize = _canvasSize(tester, find.byType(PagePreview).first);
    final landscapeSize = _canvasSize(tester, find.byType(PagePreview).last);
    expect(portraitSize.height, greaterThan(portraitSize.width));
    expect(landscapeSize.height, lessThan(landscapeSize.width));
  });
}

Size _canvasSize(WidgetTester tester, Finder previewFinder) {
  final canvas = find.descendant(
    of: previewFinder,
    matching: find.byType(CustomPaint),
  );
  return tester.renderObject<RenderCustomPaint>(canvas).size;
}