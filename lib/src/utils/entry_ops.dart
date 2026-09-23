import '../models/print_entry.dart';
import '../models/selected_image.dart';

/// All images across [entries], in order.
List<SelectedImage> allImages(List<PrintEntry> entries) => [
      for (final entry in entries) ...entry.images,
    ];

/// Removes the whole entries [gone] (by identity). Images keep their
/// references; disposal is the caller's responsibility.
List<PrintEntry> withoutEntries(List<PrintEntry> entries, Iterable<PrintEntry> gone) {
  final goneIds = gone.toSet();
  return [
    for (final entry in entries)
      if (!goneIds.contains(entry)) entry,
  ];
}

/// Moves the entries [dragged] (in this exact order) so the block starts at
/// [targetIndex]: the slot of the entry the drag ended on, or `entries.length`
/// when dropping past the last entry. Dropping on an entry replaces that
/// entry's position, both for rightward and leftward moves.
List<PrintEntry> moveEntriesTo(
  List<PrintEntry> entries,
  List<PrintEntry> dragged,
  int targetIndex,
) {
  if (dragged.isEmpty) return entries;
  final draggedIds = dragged.toSet();
  if (draggedIds.length != dragged.length || draggedIds.containsAll(entries)) {
    return entries;
  }

  final result = <PrintEntry>[
    for (final entry in entries)
      if (!draggedIds.contains(entry)) entry,
  ];

  result.insertAll(targetIndex.clamp(0, result.length), dragged);
  return result;
}

/// Removes the images [images] from wherever they live (single pages or grid
/// cells). Entries that become empty disappear; grids that only partially
/// lose images stay grids. Images keep their references.
List<PrintEntry> removeImages(
  List<PrintEntry> entries,
  Iterable<SelectedImage> images,
) {
  final ids = images.toSet();
  if (ids.isEmpty) return List.of(entries);

  final result = <PrintEntry>[];
  for (final entry in entries) {
    if (entry.images.any(ids.contains)) {
      final kept = entry.images.where((image) => !ids.contains(image)).toList();
      if (kept.isNotEmpty) {
        result.add(_withImages(entry, kept));
      }
    } else {
      result.add(entry);
    }
  }
  return result;
}

/// Moves the images [images] (removing them from grid cells or single pages
/// first) so they reappear as single pages with the block starting at
/// [targetIndex]: the slot of the entry the drag ended on.
List<PrintEntry> moveImagesTo(
  List<PrintEntry> entries,
  List<SelectedImage> images,
  int targetIndex,
) {
  final ids = images.toSet();
  if (ids.isEmpty) return entries;

  final without = removeImages(entries, ids);
  final result = List<PrintEntry>.of(without);
  result.insertAll(
    targetIndex.clamp(0, without.length),
    images.map(ImageEntry.new),
  );
  return result;
}

/// Adds the images [images] into the grid [grid], removing them from any
/// other entry first. Images already inside [grid] are left untouched. When
/// [at] is given the images are inserted at that position inside the grid
/// (clamped to the grid's bounds, default: appended).
List<PrintEntry> addImagesToGrid(
  List<PrintEntry> entries,
  GridEntry grid,
  Iterable<SelectedImage> images, {
  int? at,
}) {
  final incoming = images.where((image) => !grid.images.contains(image)).toList();
  if (incoming.isEmpty) return entries;

  var without = removeImages(entries, incoming);
  final index = without.indexOf(grid);
  if (index < 0) return entries;

  final current = without[index] as GridEntry;
  final merged = List<SelectedImage>.of(current.images);
  merged.insertAll(
    (at ?? current.images.length).clamp(0, current.images.length),
    incoming,
  );
  final result = List<PrintEntry>.of(without);
  result[index] = GridEntry(
    images: merged,
    rows: current.rows,
    cols: current.cols,
    gapMm: current.gapMm,
  );
  return result;
}

/// Moves [images] (which must already belong to [grid]) so the block starts at
/// [targetIndex] inside the grid: the cell the drop ended on. Only the order
/// inside the grid changes.
List<PrintEntry> moveImagesWithinGrid(
  List<PrintEntry> entries,
  GridEntry grid,
  List<SelectedImage> images,
  int targetIndex,
) {
  final ids = images.toSet();
  if (ids.isEmpty || !images.every(grid.images.contains)) return entries;

  final index = entries.indexOf(grid);
  if (index < 0) return entries;

  final rest = grid.images.where((image) => !ids.contains(image)).toList();
  rest.insertAll(targetIndex.clamp(0, rest.length), images);

  final result = List<PrintEntry>.of(entries);
  result[index] = GridEntry(
    images: rest,
    rows: grid.rows,
    cols: grid.cols,
    gapMm: grid.gapMm,
  );
  return result;
}

/// Replaces [grid] with its images as standalone single pages at the same
/// position.
List<PrintEntry> ungroupImages(List<PrintEntry> entries, GridEntry grid) {
  final index = entries.indexOf(grid);
  if (index < 0) return entries;
  return [
    ...entries.sublist(0, index),
    for (final image in grid.images) ImageEntry(image),
    ...entries.sublist(index + 1),
  ];
}

/// Groups the images [images] into a new grid inserted at [at] (a slot in the
/// *original* list), removing them from their previous entries.
List<PrintEntry> groupImages(
  List<PrintEntry> entries,
  List<SelectedImage> images,
  int at, {
  required int rows,
  required int cols,
  double gapMm = 0,
}) {
  final ids = images.toSet();
  if (ids.length != images.length || images.isEmpty) return entries;

  final without = removeImages(entries, images);
  final insert = at.clamp(0, without.length);
  final result = List<PrintEntry>.of(without);
  result.insert(
    insert,
    GridEntry(images: List.of(images), rows: rows, cols: cols, gapMm: gapMm),
  );
  return result;
}

/// Replaces the grid [grid] with a copy that has the given [rows]/[cols].
List<PrintEntry> setGridDimensions(
  List<PrintEntry> entries,
  GridEntry grid, {
  required int rows,
  required int cols,
}) {
  final index = entries.indexOf(grid);
  if (index < 0) return entries;
  final result = List<PrintEntry>.of(entries);
  result[index] = GridEntry(
    images: grid.images,
    rows: rows,
    cols: cols,
    gapMm: grid.gapMm,
  );
  return result;
}

/// Replaces the grid [grid] with a copy that has the given [gapMm].
List<PrintEntry> setGridGap(
  List<PrintEntry> entries,
  GridEntry grid,
  double gapMm,
) {
  final index = entries.indexOf(grid);
  if (index < 0) return entries;
  final result = List<PrintEntry>.of(entries);
  result[index] = GridEntry(
    images: grid.images,
    rows: grid.rows,
    cols: grid.cols,
    gapMm: gapMm,
  );
  return result;
}

PrintEntry _withImages(PrintEntry entry, List<SelectedImage> images) =>
    switch (entry) {
      ImageEntry() => ImageEntry(images.first),
      GridEntry(:final rows, :final cols, :final gapMm) =>
        GridEntry(images: images, rows: rows, cols: cols, gapMm: gapMm),
    };