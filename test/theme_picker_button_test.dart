import 'package:cetakeero/src/models/theme_selection.dart';
import 'package:cetakeero/src/widgets/theme_picker_button.dart';
import 'package:catppuccin_flutter/catppuccin_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('menu lists all four flavors', (tester) async {
    ThemeSelection? picked;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: AppBar(
            actions: [
              ThemePickerButton(
                current: defaultThemeSelection,
                onChanged: (selection) => picked = selection,
              ),
            ],
          ),
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.palette_outlined));
    await tester.pumpAndSettle();

    expect(find.text('Latte'), findsOneWidget);
    expect(find.text('Frappe'), findsOneWidget);
    expect(find.text('Macchiato'), findsOneWidget);
    expect(find.text('Mocha'), findsOneWidget);

    expect(picked, isNull);
  });

  testWidgets('picking a flavor submenu color reports the selection',
      (tester) async {
    ThemeSelection? picked;
    final current = defaultThemeSelection;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: AppBar(
            actions: [
              ThemePickerButton(
                current: current,
                onChanged: (selection) => picked = selection,
              ),
            ],
          ),
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.palette_outlined));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(SubmenuButton).at(1));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Teal'));
    await tester.pumpAndSettle();

    expect(picked, isNotNull);
    expect(picked!.flavor, catppuccin.frappe);
    expect(picked!.accent, catppuccin.frappe.teal);
  });
}