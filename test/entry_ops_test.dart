import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:cetakeero/src/models/print_entry.dart';
import 'package:cetakeero/src/models/selected_image.dart';
import 'package:cetakeero/src/print/print_image.dart';
import 'package:cetakeero/src/utils/entry_ops.dart';
import 'package:flutter_test/flutter_test.dart';

const _oneByOnePng =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==';

Future<SelectedImage> _sel(String name) async {
  final completer = Completer<ui.Image>();
  ui.decodeImageFromList(base64Decode(_oneByOnePng), completer.complete);
  return SelectedImage(
    printImage: PrintImage(
      name: name,
      bytes: Uint8List(0),
      width: 10,
      height: 10,
    ),
    preview: await completer.future,
  );
}

void main() {
  late List<SelectedImage> imgs;

  setUpAll(() async {
    imgs = [
      await _sel('a'),
      await _sel('b'),
      await _sel('c'),
      await _sel('d'),
      await _sel('e'),
    ];
  });

  List<PrintEntry> singles() =>
      [for (final image in imgs) ImageEntry(image)];

  List<String> namesOf(List<PrintEntry> entries) => [
        for (final entry in entries)
          for (final image in entry.images) image.printImage.name,
      ];

  group('moveEntriesTo', () {
    test('moves a checked block to a later slot', () {
      final entries = singles();
      final result = moveEntriesTo(entries, [entries[1], entries[3]], 4);
      expect(namesOf(result), ['a', 'c', 'e', 'b', 'd']);
    });

    test('drops an entry onto a later thumb to replace its position', () {
      final entries = singles();
      // Dragging #1 onto #4 (index 3) must place it at the #4 slot.
      final result = moveEntriesTo(entries, [entries[0]], 3);
      expect(namesOf(result), ['b', 'c', 'd', 'a', 'e']);
      // Dragging #5 onto #4 (index 3) must place it at the #4 slot.
      final result5 = moveEntriesTo(entries, [entries[4]], 3);
      expect(namesOf(result5), ['a', 'b', 'c', 'e', 'd']);
    });

    test('moves a checked block to the front', () {
      final entries = singles();
      final result = moveEntriesTo(entries, [entries[1], entries[3]], 0);
      expect(namesOf(result), ['b', 'd', 'a', 'c', 'e']);
    });

    test('moves one entry to the end', () {
      final entries = singles();
      final result = moveEntriesTo(entries, [entries[0]], entries.length);
      expect(namesOf(result), ['b', 'c', 'd', 'e', 'a']);
    });
  });

  group('removeImages', () {
    test('removes whole single entries', () {
      final entries = singles();
      final result = removeImages(entries, [imgs[0], imgs[2]]);
      expect(namesOf(result), ['b', 'd', 'e']);
    });

    test('removes grid cells and keeps the grid', () {
      final grid = GridEntry(images: imgs.sublist(0, 4), rows: 2, cols: 2);
      final entries = [ImageEntry(imgs[4]), grid];
      final result = removeImages(entries, [imgs[1], imgs[3]]);
      expect(result, hasLength(2));
      expect((result[1] as GridEntry).images, [imgs[0], imgs[2]]);
      expect((result[1] as GridEntry).rows, 2);
      expect((result[1] as GridEntry).cols, 2);
    });

    test('drops a grid that loses all its cells', () {
      final grid = GridEntry(images: imgs.sublist(0, 2), rows: 1, cols: 2);
      final result = removeImages([grid], imgs.sublist(0, 2));
      expect(result, isEmpty);
    });
  });

  group('moveImagesTo', () {
    test('pulls a cell out of a grid to the end of the queue', () {
      final grid = GridEntry(images: [imgs[0], imgs[1], imgs[2]], rows: 1, cols: 3);
      final entries = [grid, ImageEntry(imgs[3])];
      final result = moveImagesTo(entries, [imgs[1]], 2);
      expect(result, hasLength(3));
      expect((result[0] as GridEntry).images, [imgs[0], imgs[2]]);
      expect((result[1] as ImageEntry).image, imgs[3]);
      expect((result[2] as ImageEntry).image, imgs[1]);
    });

    test('moves a cell to the start of the queue', () {
      final grid = GridEntry(images: [imgs[0], imgs[1]], rows: 1, cols: 2);
      final result = moveImagesTo([grid, ImageEntry(imgs[2])], [imgs[1]], 0);
      expect(namesOf(result), ['b', 'a', 'c']);
    });
  });

  group('addImagesToGrid', () {
    test('adds checked images into the grid', () {
      final grid = GridEntry(images: [imgs[0], imgs[1]], rows: 2, cols: 2);
      final entries = [grid, ImageEntry(imgs[2]), ImageEntry(imgs[3])];
      final result = addImagesToGrid(entries, grid, [imgs[2], imgs[3]]);
      expect(result, hasLength(1));
      expect(namesOf(result), ['a', 'b', 'c', 'd']);
      expect((result[0] as GridEntry).rows, 2);
    });

    test('inserts images at the given index inside the grid', () {
      final grid = GridEntry(images: [imgs[0], imgs[1]], rows: 2, cols: 2);
      final entries = [grid, ImageEntry(imgs[2])];
      final result = addImagesToGrid(entries, grid, [imgs[2]], at: 1);
      expect(namesOf(result), ['a', 'c', 'b']);
      expect(result, hasLength(1));
    });

    test('clamps the insert index into the grid bounds', () {
      final grid = GridEntry(images: [imgs[0], imgs[1]], rows: 2, cols: 2);
      final entries = [grid, ImageEntry(imgs[2])];
      final result = addImagesToGrid(entries, grid, [imgs[2]], at: 99);
      expect(namesOf(result), ['a', 'b', 'c']);
    });

    test('ignores images already inside the grid', () {
      final grid = GridEntry(images: [imgs[0], imgs[1]], rows: 2, cols: 2);
      final entries = [grid, ImageEntry(imgs[2])];
      final result = addImagesToGrid(entries, grid, [imgs[0], imgs[2]]);
      expect(namesOf(result), ['a', 'b', 'c']);
    });
  });

  group('moveImagesWithinGrid', () {
    test('re-sorts cells so the block starts at the target index', () {
      final grid =
          GridEntry(images: [imgs[0], imgs[1], imgs[2]], rows: 1, cols: 3);
      final result = moveImagesWithinGrid([grid], grid, [imgs[2]], 0);
      expect(namesOf(result), ['c', 'a', 'b']);
      expect(result, hasLength(1));
    });

    test('moves a block of cells', () {
      final grid = GridEntry(
        images: [imgs[0], imgs[1], imgs[2], imgs[3]],
        rows: 2,
        cols: 2,
      );
      final result =
          moveImagesWithinGrid([grid], grid, [imgs[0], imgs[1]], 2);
      expect(namesOf(result), ['c', 'd', 'a', 'b']);
    });

    test('leaves the grid untouched when images are not its cells', () {
      final grid = GridEntry(images: [imgs[0], imgs[1]], rows: 1, cols: 2);
      final entries = [grid, ImageEntry(imgs[2])];
      final result = moveImagesWithinGrid(entries, grid, [imgs[2]], 0);
      expect(identical(result, entries), isTrue);
    });

    test('preserves the gap', () {
      final grid = GridEntry(
        images: [imgs[0], imgs[1], imgs[2]],
        rows: 1,
        cols: 3,
        gapMm: 6,
      );
      final updated =
          moveImagesWithinGrid([grid], grid, [imgs[2]], 0).first as GridEntry;
      expect(updated.gapMm, 6);
    });
  });

  group('ungroupImages', () {
    test('splits a grid into standalone pages at the same position', () {
      final grid = GridEntry(images: imgs.sublist(0, 3), rows: 1, cols: 3);
      final entries = [ImageEntry(imgs[3]), grid, ImageEntry(imgs[4])];
      final result = ungroupImages(entries, grid);
      expect(result, hasLength(5));
      expect(result[0], isA<ImageEntry>());
      expect((result[1] as ImageEntry).image, imgs[0]);
      expect((result[2] as ImageEntry).image, imgs[1]);
      expect((result[3] as ImageEntry).image, imgs[2]);
      expect((result[4] as ImageEntry).image, imgs[4]);
    });

    test('returns entries unchanged when the grid is absent', () {
      final entries = singles();
      final missing = GridEntry(images: [imgs[0]], rows: 1, cols: 1);
      expect(identical(ungroupImages(entries, missing), entries), isTrue);
    });
  });

  group('groupImages', () {
    test('creates a grid at the first checked position', () {
      final entries = singles();
      final result = groupImages(
        entries,
        [imgs[1], imgs[2], imgs[3]],
        1,
        rows: 2,
        cols: 2,
      );
      expect(namesOf(result), ['a', 'b', 'c', 'd', 'e']);
      expect(result[0], isA<ImageEntry>());
      final grid = result[1] as GridEntry;
      expect(grid.images, [imgs[1], imgs[2], imgs[3]]);
      expect(grid.rows, 2);
      expect(grid.cols, 2);
    });

    test('creates a grid at the front', () {
      final entries = singles();
      final result = groupImages(
        entries,
        [imgs[0], imgs[1]],
        0,
        rows: 1,
        cols: 2,
      );
      expect(result.first, isA<GridEntry>());
      expect(namesOf(result), ['a', 'b', 'c', 'd', 'e']);
    });
  });

  group('setGridDimensions', () {
    test('keeps images and updates rows/cols', () {
      final grid = GridEntry(images: imgs.sublist(0, 3), rows: 1, cols: 3);
      final result = setGridDimensions([grid], grid, rows: 2, cols: 2);
      final updated = result.first as GridEntry;
      expect(updated.images, imgs.sublist(0, 3));
      expect(updated.rows, 2);
      expect(updated.cols, 2);
    });
  });

  group('grid gap', () {
    test('setGridGap updates the gap', () {
      final grid = GridEntry(
        images: imgs.sublist(0, 3),
        rows: 2,
        cols: 2,
        gapMm: 4,
      );
      final result = setGridGap([grid], grid, 6);
      final updated = result.first as GridEntry;
      expect(updated.gapMm, 6);
      expect(updated.rows, 2);
      expect(updated.cols, 2);
      expect(updated.images, hasLength(3));
    });

    test('setGridDimensions preserves the gap', () {
      final grid = GridEntry(
        images: imgs.sublist(0, 3),
        rows: 1,
        cols: 3,
        gapMm: 5,
      );
      final updated =
          setGridDimensions([grid], grid, rows: 2, cols: 2).first as GridEntry;
      expect(updated.gapMm, 5);
      expect(updated.rows, 2);
    });

    test('addImagesToGrid preserves the gap', () {
      final grid = GridEntry(
        images: [imgs[0], imgs[1]],
        rows: 2,
        cols: 2,
        gapMm: 7,
      );
      final entries = [grid, ImageEntry(imgs[2])];
      final updated =
          (addImagesToGrid(entries, grid, [imgs[2]]).first as GridEntry);
      expect(updated.gapMm, 7);
      expect(updated.images, hasLength(3));
    });

    test('removeImages keeps the gap when cells are removed', () {
      final grid = GridEntry(
        images: imgs.sublist(0, 4),
        rows: 2,
        cols: 2,
        gapMm: 3,
      );
      final entries = [ImageEntry(imgs[4]), grid];
      final updated =
          (removeImages(entries, [imgs[1]]).last as GridEntry);
      expect(updated.gapMm, 3);
      expect(updated.images, [imgs[0], imgs[2], imgs[3]]);
    });
  });

  group('defaultGridSize', () {
    test('produces a roughly square layout', () {
      expect(defaultGridSize(2), (1, 2));
      expect(defaultGridSize(3), (2, 2));
      expect(defaultGridSize(4), (2, 2));
      expect(defaultGridSize(5), (2, 3));
      expect(defaultGridSize(6), (2, 3));
      expect(defaultGridSize(9), (3, 3));
      expect(defaultGridSize(0), (1, 1));
      expect(defaultGridSize(-3), (1, 1));
    });
  });
}