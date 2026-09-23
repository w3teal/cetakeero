import 'dart:convert';
import 'dart:typed_data';

import 'package:cetakeero/src/models/print_settings.dart';
import 'package:cetakeero/src/models/theme_selection.dart';
import 'package:cetakeero/src/screens/home_screen.dart';
import 'package:cetakeero/src/widgets/grid_preview.dart';
import 'package:cetakeero/src/widgets/page_preview.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _oneByOnePng =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==';

Future<void> _drop(
  WidgetTester tester,
  DropTarget target, {
  required int count,
}) async {
  final bytes = base64Decode(_oneByOnePng);
  await tester.runAsync(() async {
    target.onDragDone?.call(DropDoneDetails(
      files: [
        for (var i = 0; i < count; i++)
          DropItemFile.fromData(
            Uint8List.fromList(bytes),
            name: '$i.png',
            mimeType: 'image/png',
          ),
      ],
      localPosition: Offset.zero,
      globalPosition: Offset.zero,
    ));
    await Future<void>.delayed(const Duration(milliseconds: 100));
  });
  await tester.pumpAndSettle();
}

Future<DropTarget> _pumpApp(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(1200, 1000));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      home: HomeScreen(
        currentTheme: defaultThemeSelection,
        onThemeChanged: noop,
      ),
    ),
  );
  await tester.pump();
  return tester.widget<DropTarget>(find.byType(DropTarget));
}

/// Long-presses [from] and drags to [to], the gesture a finder drag would use.
Future<void> _dragCell(WidgetTester tester, Offset from, Offset to) async {
  final gesture = await tester.startGesture(from);
  await tester.pump(const Duration(milliseconds: 700));
  await gesture.moveTo(to);
  await tester.pump(const Duration(milliseconds: 100));
  await gesture.up();
  await tester.pumpAndSettle();
}

/// Global centre of a grid cell, computed from the on-screen grid's top-left.
Rect _cellRect(
  WidgetTester tester,
  Finder gridFinder,
  int cellIndex, {
  required int rows,
  required int cols,
}) {
  final cells = GridPreview.cellRectsFor(
    const PrintSettings(),
    120,
    rows: rows,
    cols: cols,
    gapMm: 0,
  );
  return cells[cellIndex].shift(tester.getTopLeft(gridFinder));
}

void main() {
  testWidgets('dropping three images then grouping two shows all three',
      (tester) async {
    final dropTarget = await _pumpApp(tester);
    await _drop(tester, dropTarget, count: 3);

    expect(find.byType(PagePreview), findsNWidgets(3),
        reason: 'three single pages after dropping three images');

    final checkboxes = find.byType(Checkbox);
    expect(checkboxes, findsNWidgets(3));
    await tester.tap(checkboxes.at(0));
    await tester.tap(checkboxes.at(1));
    await tester.pump();

    await tester.tap(find.byIcon(Icons.grid_on_outlined));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(GridPreview), findsOneWidget);
    expect(find.byType(PagePreview), findsOneWidget,
        reason: 'the un-grouped image must not disappear');
  });

  testWidgets('dragging the first image onto the third reorders it',
      (tester) async {
    final dropTarget = await _pumpApp(tester);
    await _drop(tester, dropTarget, count: 3);
    expect(find.byType(PagePreview), findsNWidgets(3));

    final start = tester.getCenter(find.byType(PagePreview).at(0));
    final target = tester.getCenter(find.byType(PagePreview).at(2));

    final gesture = await tester.startGesture(start);
    // Long press to pick up the drag, then move over the third thumb.
    await tester.pump(const Duration(milliseconds: 700));
    await gesture.moveTo(target);
    await tester.pump(const Duration(milliseconds: 100));
    await gesture.up();
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(PagePreview), findsNWidgets(3),
        reason: 'reordering must keep all three pages');
  });

  testWidgets('select all then delete removes every image', (tester) async {
    final dropTarget = await _pumpApp(tester);
    await _drop(tester, dropTarget, count: 3);

    await tester.tap(find.byIcon(Icons.select_all));
    await tester.pump();

    expect(
      find.byWidgetPredicate(
          (widget) => widget is Checkbox && widget.value == true),
      findsNWidgets(3),
    );

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(PagePreview), findsNothing);
    expect(find.byType(GridPreview), findsNothing);
    expect(find.text('Choose one or more images to print'), findsOneWidget);
  });

  testWidgets('pages count appears under the Images title', (tester) async {
    final dropTarget = await _pumpApp(tester);
    expect(find.text('0 pages'), findsOneWidget);
    await _drop(tester, dropTarget, count: 2);
    expect(find.text('2 pages'), findsOneWidget);
    expect(find.text('1 page'), findsNothing);
  });

  group('Add to grid rules', () {
    testWidgets('is disabled when a grid and an image are selected',
        (tester) async {
      final dropTarget = await _pumpApp(tester);
      await _drop(tester, dropTarget, count: 3);

      await tester.tap(find.byType(Checkbox).at(0));
      await tester.tap(find.byType(Checkbox).at(1));
      await tester.pump();
      await tester.tap(find.byIcon(Icons.grid_on_outlined));
      await tester.pumpAndSettle();

      expect(find.byType(GridPreview), findsOneWidget);
      await tester.tap(find.byType(Checkbox).at(1)); // the remaining page
      await tester.pump();

      final addButton = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.grid_on_outlined),
      );
      expect(addButton.onPressed, isNull,
          reason: 'grid + image selection must not allow Add to grid');
      expect(find.text('Grid'), findsOneWidget,
          reason: 'a single checked grid keeps its toolbar');
    });

    testWidgets('is disabled and toolbar hidden when two grids are selected',
        (tester) async {
      final dropTarget = await _pumpApp(tester);
      await _drop(tester, dropTarget, count: 5);

      await tester.tap(find.byType(Checkbox).at(0));
      await tester.tap(find.byType(Checkbox).at(1));
      await tester.pump();
      await tester.tap(find.byIcon(Icons.grid_on_outlined));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(Checkbox).at(1));
      await tester.tap(find.byType(Checkbox).at(2));
      await tester.pump();
      // The first grid is still checked: the add-to-grid button is now
      // disabled, so deselect it before creating a second grid.
      await tester.tap(find.byType(Checkbox).at(0));
      await tester.pump();
      await tester.tap(find.byIcon(Icons.grid_on_outlined));
      await tester.pumpAndSettle();

      expect(find.byType(GridPreview), findsNWidgets(2));
      await tester.tap(find.byType(Checkbox).at(0)); // grid1
      await tester.pump();

      final addButton = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.grid_on_outlined),
      );
      expect(addButton.onPressed, isNull);
      expect(find.text('Grid'), findsNothing,
          reason: 'two checked grids must not show grid toolbar');
      expect(find.byType(DropdownButton<int>), findsNothing);
    });
  });

  testWidgets('small grid dimensions are rejected with a message',
      (tester) async {
    final dropTarget = await _pumpApp(tester);
    await _drop(tester, dropTarget, count: 2);

    await tester.tap(find.byType(Checkbox).at(0));
    await tester.tap(find.byType(Checkbox).at(1));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.grid_on_outlined));
    await tester.pumpAndSettle();

    expect(find.text('Grid'), findsOneWidget);
    await tester.tap(find.byType(DropdownButton<int>).at(1)); // cols
    await tester.pumpAndSettle();
    await tester.tap(find.text('1').last);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.textContaining('The grid layout must fit'), findsOneWidget);
    expect(
      tester.widget<DropdownButton<int>>(find.byType(DropdownButton<int>).at(1)).value,
      isNot(1),
      reason: 'the rejected dimension must not be applied',
    );
  });

  group('grid drag mode', () {
    testWidgets('the mode toggle hides thumbnails chrome', (tester) async {
      final dropTarget = await _pumpApp(tester);
      await _drop(tester, dropTarget, count: 2);

      await tester.tap(find.byType(Checkbox).at(0));
      await tester.tap(find.byType(Checkbox).at(1));
      await tester.pump();
      await tester.tap(find.byIcon(Icons.grid_on_outlined));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.drag_indicator), findsOneWidget,
          reason: 'page drag mode is the default');
      expect(find.byType(Checkbox), findsNWidgets(1),
          reason: 'the single grid entry shows its chrome in page mode');

      await tester.tap(find.byIcon(Icons.drag_indicator));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.grid_on), findsOneWidget,
          reason: 'grid mode is active');
      expect(find.byType(Checkbox), findsNothing,
          reason: 'thumbnails keep their chrome hidden in grid mode');
      expect(find.text('1×2'), findsNothing, reason: 'grid pill hidden');
      expect(find.text('Grid'), findsNothing,
          reason: 'switching modes clears the selection so no grid toolbar');
      expect(find.byType(DropdownButton<int>), findsNothing,
          reason: 'no grid is selected in grid mode');

      await tester.tap(find.byIcon(Icons.grid_on));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.drag_indicator), findsOneWidget);
      expect(find.byType(Checkbox), findsNWidgets(1),
          reason: 'leaving grid mode brings the chrome back');
    });

    testWidgets('re-sorts a cell dragged onto another cell of the same grid',
        (tester) async {
      final dropTarget = await _pumpApp(tester);
      await _drop(tester, dropTarget, count: 3);

      await tester.tap(find.byType(Checkbox).at(0));
      await tester.tap(find.byType(Checkbox).at(1));
      await tester.tap(find.byType(Checkbox).at(2));
      await tester.pump();
      await tester.tap(find.byIcon(Icons.grid_on_outlined));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.drag_indicator));
      await tester.pumpAndSettle();

      final gridFinder = find.byType(GridPreview);
      final before =
          tester.widget<GridPreview>(gridFinder).images.toList();
      expect(before, hasLength(3),
          reason: 'a 3-image grid on a 2x2 layout');

      await _dragCell(
        tester,
        _cellRect(tester, gridFinder, 0, rows: 2, cols: 2).center,
        _cellRect(tester, gridFinder, 1, rows: 2, cols: 2).center,
      );

      expect(tester.takeException(), isNull);
      final after =
          tester.widget<GridPreview>(gridFinder).images.toList();
      expect(after, hasLength(3), reason: 're-sorting keeps every image');
      expect(after[0], same(before[1]),
          reason: 'the first cell now holds the image dragged onto it');
      expect(after[1], same(before[0]));
      expect(after[2], same(before[2]));
    });

    testWidgets('dragging a cell onto a standalone page creates a grid',
        (tester) async {
      final dropTarget = await _pumpApp(tester);
      await _drop(tester, dropTarget, count: 3);

      await tester.tap(find.byType(Checkbox).at(0));
      await tester.tap(find.byType(Checkbox).at(1));
      await tester.pump();
      await tester.tap(find.byIcon(Icons.grid_on_outlined));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.drag_indicator));
      await tester.pumpAndSettle();

      final gridFinder = find.byType(GridPreview);
      await _dragCell(
        tester,
        _cellRect(tester, gridFinder, 0, rows: 1, cols: 2).center,
        tester.getCenter(find.byType(PagePreview)),
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(GridPreview), findsOneWidget,
          reason: 'the cell and the page merged into one grid');
      expect(tester.widget<GridPreview>(gridFinder).images, hasLength(2),
          reason: 'one grid page holds the dragged-out image');
      expect(find.byType(PagePreview), findsOneWidget,
          reason: 'the source grid lost an image and collapsed to its page');
    });

    testWidgets('pulls a cell out onto empty space as a standalone page',
        (tester) async {
      final dropTarget = await _pumpApp(tester);
      await _drop(tester, dropTarget, count: 3);

      await tester.tap(find.byType(Checkbox).at(0));
      await tester.tap(find.byType(Checkbox).at(1));
      await tester.tap(find.byType(Checkbox).at(2));
      await tester.pump();
      await tester.tap(find.byIcon(Icons.grid_on_outlined));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.drag_indicator));
      await tester.pumpAndSettle();

      final gridFinder = find.byType(GridPreview);
      expect(tester.widget<GridPreview>(gridFinder).images, hasLength(3));

      await _dragCell(
        tester,
        _cellRect(tester, gridFinder, 0, rows: 2, cols: 2).center,
        tester.getCenter(gridFinder) + const Offset(80, 0),
      );

      expect(tester.takeException(), isNull);
      expect(tester.widget<GridPreview>(gridFinder).images, hasLength(2),
          reason: 'the grid lost the dragged-out image');
      expect(find.byType(PagePreview), findsOneWidget,
          reason: 'the dragged-out cell became its own page');
    });

    testWidgets('a grid left with a single image becomes a standalone page',
        (tester) async {
      final dropTarget = await _pumpApp(tester);
      await _drop(tester, dropTarget, count: 3);

      await tester.tap(find.byType(Checkbox).at(0));
      await tester.tap(find.byType(Checkbox).at(1));
      await tester.pump();
      await tester.tap(find.byIcon(Icons.grid_on_outlined));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.drag_indicator));
      await tester.pumpAndSettle();

      final gridFinder = find.byType(GridPreview);
      expect(tester.widget<GridPreview>(gridFinder).images, hasLength(2));

      await _dragCell(
        tester,
        _cellRect(tester, gridFinder, 0, rows: 1, cols: 2).center,
        tester.getTopLeft(gridFinder) + const Offset(60, 220),
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(GridPreview), findsNothing,
          reason: 'a single remaining image is a standalone page, not a grid');
      expect(find.byType(PagePreview), findsNWidgets(3),
          reason: 'pulled-out image, collapsed grid image and the page');
    });

    testWidgets('page mode drags a grid onto another grid to reorder',
        (tester) async {
      final dropTarget = await _pumpApp(tester);
      await _drop(tester, dropTarget, count: 4);

      await tester.tap(find.byType(Checkbox).at(0));
      await tester.tap(find.byType(Checkbox).at(1));
      await tester.pump();
      await tester.tap(find.byIcon(Icons.grid_on_outlined));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(Checkbox).at(1));
      await tester.tap(find.byType(Checkbox).at(2));
      await tester.pump();
      await tester.tap(find.byType(Checkbox).at(0));
      await tester.pump();
      await tester.tap(find.byIcon(Icons.grid_on_outlined));
      await tester.pumpAndSettle();

      expect(find.byType(GridPreview), findsNWidgets(2));

      final gridOne = find.byType(GridPreview).at(0);
      final gridTwo = find.byType(GridPreview).at(1);
      final beforeOne =
          tester.widget<GridPreview>(gridOne).images.toList();
      final beforeTwo =
          tester.widget<GridPreview>(gridTwo).images.toList();

      await _dragCell(
        tester,
        tester.getCenter(gridOne),
        tester.getCenter(gridTwo),
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(GridPreview), findsNWidgets(2),
          reason: 'grids must never merge in page mode');
      final after = find.byType(GridPreview);
      expect(tester.widget<GridPreview>(after.at(0)).images,
          isNot(equals(beforeOne)),
          reason: 'the dragged grid moved away from the front');
      expect(tester.widget<GridPreview>(after.at(0)).images, equals(beforeTwo),
          reason: 'the target grid now sits first');
      expect(tester.widget<GridPreview>(after.at(1)).images, equals(beforeOne),
          reason: 'the dragged grid now sits after the target grid');
    });

    testWidgets('moves an image from one grid into another', (tester) async {
      final dropTarget = await _pumpApp(tester);
      await _drop(tester, dropTarget, count: 5);

      await tester.tap(find.byType(Checkbox).at(0));
      await tester.tap(find.byType(Checkbox).at(1));
      await tester.pump();
      await tester.tap(find.byIcon(Icons.grid_on_outlined));
      await tester.pumpAndSettle();

      // Deselect the first grid before creating the second.
      await tester.tap(find.byType(Checkbox).at(1));
      await tester.tap(find.byType(Checkbox).at(2));
      await tester.tap(find.byType(Checkbox).at(3));
      await tester.tap(find.byType(Checkbox).at(0)); // grid1
      await tester.pump();
      await tester.tap(find.byIcon(Icons.grid_on_outlined));
      await tester.pumpAndSettle();
      expect(find.byType(GridPreview), findsNWidgets(2));

      await tester.tap(find.byIcon(Icons.drag_indicator));
      await tester.pumpAndSettle();

      final gridAFinder = find.byType(GridPreview).at(0);
      final gridBFinder = find.byType(GridPreview).at(1);
      final av0 = GridPreview.cellRectsFor(const PrintSettings(), 120,
              rows: 1, cols: 2)
          [0]
          .center;

      await _dragCell(
        tester,
        av0 + tester.getTopLeft(gridAFinder),
        _cellRect(tester, gridBFinder, 3, rows: 2, cols: 2).center,
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(GridPreview), findsOneWidget,
          reason: 'the 2-image source grid collapsed to a single page');
      expect(tester.widget<GridPreview>(find.byType(GridPreview)).images,
          hasLength(4),
          reason: 'the target grid gained an image on its empty cell');
      expect(find.byType(PagePreview), findsOneWidget,
          reason: 'the collapsed source grid image became a standalone page');
    });

    testWidgets('inserts a standalone page into an empty grid cell',
        (tester) async {
      final dropTarget = await _pumpApp(tester);
      await _drop(tester, dropTarget, count: 4);

      await tester.tap(find.byType(Checkbox).at(0));
      await tester.tap(find.byType(Checkbox).at(1));
      await tester.tap(find.byType(Checkbox).at(2));
      await tester.pump();
      await tester.tap(find.byIcon(Icons.grid_on_outlined));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.drag_indicator));
      await tester.pumpAndSettle();

      final gridFinder = find.byType(GridPreview);
      await _dragCell(
        tester,
        tester.getCenter(find.byType(PagePreview)),
        _cellRect(tester, gridFinder, 3, rows: 2, cols: 2).center,
      );

      expect(tester.takeException(), isNull);
      expect(
        tester.widget<GridPreview>(gridFinder).images.toList(),
        hasLength(4),
        reason: 'the dropped page joined the grid on its empty cell',
      );
      expect(find.byType(PagePreview), findsNothing);
    });
  });

  testWidgets('ungroup splits a grid back into single pages', (tester) async {
    final dropTarget = await _pumpApp(tester);
    await _drop(tester, dropTarget, count: 2);

    await tester.tap(find.byType(Checkbox).at(0));
    await tester.tap(find.byType(Checkbox).at(1));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.grid_on_outlined));
    await tester.pumpAndSettle();
    expect(find.byType(GridPreview), findsOneWidget);
    expect(find.text('1 page'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.grid_off));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(GridPreview), findsNothing);
    expect(find.byType(PagePreview), findsNWidgets(2));
    expect(find.text('2 pages'), findsOneWidget);
  });
}

void noop(ThemeSelection selection) {}