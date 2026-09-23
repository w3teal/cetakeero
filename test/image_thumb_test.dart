import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:cetakeero/src/widgets/image_thumb.dart';
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
  testWidgets('renders a cover thumbnail with label and remove button',
      (tester) async {
    final image = await tester.runAsync(_decode);
    addTearDown(image!.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ImageThumb(
            image: image,
            label: '#1',
            size: 120,
            onRemove: () {},
          ),
        ),
      ),
    );

    expect(find.byType(ImageThumb), findsOneWidget);
    expect(find.text('#1'), findsOneWidget);
    expect(find.byIcon(Icons.close), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('does not overflow and stays square on any size',
      (tester) async {
    final image = await tester.runAsync(_decode);
    addTearDown(image!.dispose);

    for (final size in [40.0, 120.0, 220.0]) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: ImageThumb(
                image: image,
                label: '#7',
                size: size,
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull, reason: 'size $size');
      expect(find.text('#7'), findsOneWidget);
    }
  });
}