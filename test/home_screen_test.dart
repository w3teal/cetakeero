import 'package:cetakeero/src/models/theme_selection.dart';
import 'package:cetakeero/src/screens/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
      'renders the home screen with settings and a disabled print button',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          currentTheme: defaultThemeSelection,
          onThemeChanged: _noop,
        ),
      ),
    );

    expect(find.text('cetakeero'), findsOneWidget);
    expect(find.text('Choose one or more images to print'), findsOneWidget);
    expect(find.byIcon(Icons.palette_outlined), findsOneWidget);
    expect(find.text('Page size'), findsWidgets);
    expect(find.text('Portrait'), findsOneWidget);
    expect(find.text('Landscape'), findsOneWidget);
    expect(find.text('Contain'), findsOneWidget);
    expect(find.text('Cover'), findsOneWidget);
    expect(find.text('10 mm'), findsOneWidget);

    final printButton = tester.widget<FilledButton>(
      find.ancestor(
        of: find.text('Add images to print'),
        matching: find.byType(FilledButton),
      ),
    );
    expect(printButton.onPressed, isNull);
  });
}

void _noop(ThemeSelection selection) {}