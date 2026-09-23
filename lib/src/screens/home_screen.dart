import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';

import '../layout/page_layout.dart';
import '../models/print_entry.dart';
import '../models/print_settings.dart';
import '../models/selected_image.dart';
import '../models/theme_selection.dart';
import '../print/print_document.dart';
import '../print/print_image.dart';
import '../utils/entry_ops.dart';
import '../widgets/grid_preview.dart';
import '../widgets/page_preview.dart';
import '../widgets/theme_picker_button.dart';

/// The payload carried by an in-app drag of print queue entries.
class _DragPayload {
  _DragPayload.entries(this.entries) : images = const [];

  _DragPayload.images(this.images) : entries = const [];

  /// Whole entries being moved together (reorder, merge into grids).
  final List<PrintEntry> entries;

  /// Individual images being pulled out of a grid.
  final List<SelectedImage> images;

  bool get hasEntries => entries.isNotEmpty;
  bool get hasImages => images.isNotEmpty;
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.currentTheme,
    required this.onThemeChanged,
  });

  final ThemeSelection currentTheme;
  final ValueChanged<ThemeSelection> onThemeChanged;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const String gitHubSvg =
      '<svg role="img" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><title>GitHub</title><path d="M12 .297c-6.63 0-12 5.373-12 12 0 5.303 3.438 9.8 8.205 11.385.6.113.82-.258.82-.577 0-.285-.01-1.04-.015-2.04-3.338.724-4.042-1.61-4.042-1.61C4.422 18.07 3.633 17.7 3.633 17.7c-1.087-.744.084-.729.084-.729 1.205.084 1.838 1.236 1.838 1.236 1.07 1.835 2.809 1.305 3.495.998.108-.776.417-1.305.76-1.605-2.665-.3-5.466-1.332-5.466-5.93 0-1.31.465-2.38 1.235-3.22-.135-.303-.54-1.523.105-3.176 0 0 1.005-.322 3.3 1.23.96-.267 1.98-.399 3-.405 1.02.006 2.04.138 3 .405 2.28-1.552 3.285-1.23 3.285-1.23.645 1.653.24 2.873.12 3.176.765.84 1.23 1.91 1.23 3.22 0 4.61-2.805 5.625-5.475 5.92.42.36.81 1.096.81 2.22 0 1.606-.015 2.896-.015 3.286 0 .315.21.69.825.57C20.565 22.092 24 17.592 24 12.297c0-6.627-5.373-12-12-12"/></svg>';

  Future<void> goToWebPage(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url)) {
      throw 'Could not launch $url';
    }
  }

  final ScrollController _imagesScroll = ScrollController();
  final ScrollController _settingsScroll = ScrollController();

  final List<PrintEntry> _entries = [];
  final Set<PrintEntry> _checked = {};
  PrintSettings _settings = const PrintSettings();
  bool _picking = false;
  bool _printing = false;
  bool _dropActive = false;

  /// Drag mode: false drags whole page entries, true drags images inside
  /// grids (re-sort, pull out, move between grids).
  bool _gridMode = false;
  double _thumbSize = 120;

  /// The grid being edited by the toolbar. Only when exactly one grid is
  /// checked: with several grids checked they are all treated like images.
  GridEntry? get _activeGrid {
    GridEntry? found;
    for (final entry in _entries) {
      if (entry is GridEntry && _checked.contains(entry)) {
        if (found != null) return null;
        found = entry;
      }
    }
    return found;
  }

  List<PrintEntry> get _checkedEntries => [
    for (final entry in _entries)
      if (_checked.contains(entry)) entry,
  ];

  List<SelectedImage> get _checkedImages => [
    for (final entry in _checkedEntries) ...entry.images,
  ];

  /// 'Add to grid' only ever creates a new grid out of standalone images, so
  /// it is disabled whenever a grid is part of the selection.
  bool get _canAddToGrid {
    if (_entries.isEmpty) return false;
    if (_checkedEntries.any((entry) => entry is GridEntry)) return false;
    return _checkedEntries.length >= 2;
  }

  Future<void> _addImages() async {
    if (_picking) return;
    setState(() => _picking = true);
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.image,
        dialogTitle: 'Select images to print',
      );
      final loaded = <SelectedImage>[];
      for (final file in files) {
        final image = await _loadImage(file);
        if (image != null) loaded.add(image);
      }
      if (loaded.isEmpty && mounted) {
        _showMessage('Could not read the selected files.');
      }
      if (loaded.isNotEmpty && mounted) {
        _publish([..._entries, for (final image in loaded) ImageEntry(image)]);
      }
    } catch (error) {
      if (mounted) _showMessage('Failed to pick images: $error');
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<SelectedImage?> _loadImage(PlatformFile file) async {
    try {
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) return null;
      return await _loadImageBytes(file.name, bytes);
    } catch (_) {
      return null;
    }
  }

  Future<SelectedImage?> _loadImageBytes(String name, Uint8List bytes) async {
    try {
      if (bytes.isEmpty) return null;
      final preview = await _decodeImage(bytes);
      return SelectedImage(
        printImage: PrintImage(
          name: name,
          bytes: bytes,
          width: preview.width,
          height: preview.height,
        ),
        preview: preview,
      );
    } catch (_) {
      return null;
    }
  }

  Future<ui.Image> _decodeImage(Uint8List bytes) {
    final completer = Completer<ui.Image>();
    ui.decodeImageFromList(bytes, completer.complete);
    return completer.future;
  }

  void _publish(List<PrintEntry> next, {List<PrintEntry>? checked}) {
    final normalized = [
      for (final entry in next)
        if (entry is GridEntry && entry.images.length == 1)
          ImageEntry(entry.images.first)
        else
          entry,
    ];
    setState(() {
      _entries
        ..clear()
        ..addAll(normalized);
      if (checked != null) {
        _checked
          ..clear()
          ..addAll([
            for (final entry in checked)
              if (normalized.contains(entry)) entry,
          ]);
      } else {
        _checked.removeWhere((entry) => !normalized.contains(entry));
      }
    });
  }

  void _removeEntry(PrintEntry entry) {
    for (final image in entry.images) {
      image.preview.dispose();
    }
    _publish(withoutEntries(_entries, [entry]), checked: const []);
  }

  void _deleteChecked() {
    final gone = _checkedEntries;
    if (gone.isEmpty) return;
    for (final entry in gone) {
      for (final image in entry.images) {
        image.preview.dispose();
      }
    }
    _publish(withoutEntries(_entries, gone), checked: const []);
  }

  void _clearAll() {
    for (final entry in _entries) {
      for (final image in entry.images) {
        image.preview.dispose();
      }
    }
    _publish(const [], checked: const []);
  }

  void _toggleChecked(PrintEntry entry) {
    setState(() {
      if (!_checked.add(entry)) {
        _checked.remove(entry);
      }
    });
  }

  /// Groups the checked standalone images into a new grid. Grids never become
  /// part of another grid; images are added into an existing grid by dragging.
  void _addToGrid() {
    if (_entries.isEmpty ||
        _checkedEntries.any((entry) => entry is GridEntry)) {
      return;
    }
    final images = _checkedImages;
    if (images.length < 2) {
      _showMessage('Check at least two images to create a grid.');
      return;
    }
    final (rows, cols) = defaultGridSize(images.length);
    if (rows * cols < images.length) {
      _showMessage(
        'The grid layout must fit all images: a $rows × $cols grid supports '
        '${rows * cols} images but you selected $images',
      );
      return;
    }
    final at = _entries.indexWhere(_checked.contains).clamp(0, _entries.length);
    final result = groupImages(_entries, images, at, rows: rows, cols: cols);
    _publish(result, checked: [result[at]]);
  }

  void _setGridDimensions(GridEntry grid, {int? rows, int? cols}) {
    final r = rows ?? grid.rows;
    final c = cols ?? grid.cols;
    if (r * c < grid.images.length) {
      _showMessage(
        'The grid layout must fit all images: a $r × $c grid supports '
        '${r * c} of your ${grid.images.length} images.',
      );
      return;
    }
    final result = setGridDimensions(_entries, grid, rows: r, cols: c);
    if (identical(result, _entries)) return;
    final updated = result[_entries.indexOf(grid)];
    _publish(result, checked: [updated]);
  }

  void _setGridGap(GridEntry grid, double gapMm) {
    final result = setGridGap(_entries, grid, gapMm);
    if (identical(result, _entries)) return;
    final updated = result[_entries.indexOf(grid)];
    _publish(result, checked: [updated]);
  }

  void _ungroupGrid() {
    final grid = _activeGrid;
    if (grid == null) return;
    _publish(ungroupImages(_entries, grid), checked: const []);
  }

  bool _canDrop(_DragPayload payload, PrintEntry? target) {
    if (target is GridEntry) {
      // In grid mode every drop on a grid goes through its cell targets.
      if (_gridMode) return false;
      if (payload.hasImages) return payload.images.isNotEmpty;
      final dragged = payload.entries;
      if (dragged.isEmpty) return false;
      if (dragged.contains(target)) return false;
      return true;
    }

    if (payload.hasImages) return payload.images.isNotEmpty;
    final dragged = payload.entries;
    if (dragged.isEmpty) return false;
    if (target != null && dragged.contains(target)) return false;
    return true;
  }

  void _dropInto(_DragPayload payload, int targetIndex, PrintEntry? target) {
    // Grid mode: dropping an image onto a standalone page turns both into a
    // new grid. Payloads still carrying a grid entry are moved as-is instead.
    if (target is ImageEntry &&
        _gridMode &&
        payload.entries.every((entry) => entry is ImageEntry)) {
      final images = payload.hasImages
          ? payload.images
          : [
              for (final entry in payload.entries)
                if (entry is ImageEntry) entry.image,
            ];
      if (images.isNotEmpty &&
          !images.any((image) => identical(image, target.image))) {
        final total = [target.image, ...images];
        final (rows, cols) = defaultGridSize(total.length);
        final without = removeImages(_entries, total);
        final grid = GridEntry(images: List.of(total), rows: rows, cols: cols);
        final result = List<PrintEntry>.of(without)
          ..insert(targetIndex.clamp(0, without.length), grid);
        _publish(result, checked: [grid]);
        return;
      }
    }

    if (payload.hasImages) {
      _publish(
        moveImagesTo(_entries, payload.images, targetIndex),
        checked: const [],
      );
      return;
    }

    final dragged = payload.entries;
    if (dragged.isEmpty) return;
    _publish(moveEntriesTo(_entries, dragged, targetIndex), checked: const []);
  }

  /// Whether a grid cell can accept a drop. Cells never accept in page mode;
  /// in grid mode they take over all grid interaction.
  bool _canDropCell(_DragPayload payload, GridEntry grid, int cellIndex) {
    if (!_gridMode) return false;
    if (payload.hasImages) return payload.images.isNotEmpty;
    final dragged = payload.entries;
    if (dragged.isEmpty) return false;
    if (dragged.contains(grid)) return false;
    return true;
  }

  /// A drop that ended on a grid cell: an image of the same grid is
  /// re-sorted, images of another grid or of standalone pages are inserted at
  /// that cell.
  void _dropOnCell(_DragPayload payload, GridEntry grid, int cellIndex) {
    if (payload.hasImages && payload.images.isNotEmpty) {
      if (payload.images.every(grid.images.contains)) {
        _publish(
          moveImagesWithinGrid(_entries, grid, payload.images, cellIndex),
          checked: const [],
        );
        return;
      }
      _addIntoGrid(
        grid,
        payload.images.where((image) => !grid.images.contains(image)).toList(),
        cellIndex,
      );
      return;
    }

    final images = [for (final entry in payload.entries) ...entry.images]
        .where((image) => !grid.images.contains(image))
        .toList();
    _addIntoGrid(grid, images, cellIndex);
  }

  void _addIntoGrid(
    GridEntry grid,
    List<SelectedImage> incoming,
    int cellIndex,
  ) {
    if (incoming.isEmpty) return;
    if (grid.images.length + incoming.length > grid.rows * grid.cols) {
      _showMessage(
        'The grid layout must fit all images: a ${grid.rows} × ${grid.cols} grid '
        'supports ${grid.rows * grid.cols} but would hold '
        '${grid.images.length + incoming.length} images.',
      );
      return;
    }
    _publish(
      addImagesToGrid(
        _entries,
        grid,
        incoming,
        at: cellIndex.clamp(0, grid.images.length),
      ),
      checked: const [],
    );
  }

  /// Whether the empty space around the thumbnails accepts a drop: only in
  /// grid mode, so a long-pressed grid cell dropped on blank space becomes a
  /// standalone page.
  bool _canDropEmptyArea(_DragPayload payload) {
    if (!_gridMode) return false;
    return payload.hasImages && payload.images.isNotEmpty;
  }

  /// A grid cell dropped onto blank space: pull the image out of its grid as a
  /// standalone page at the end of the list.
  void _dropEmptyArea(_DragPayload payload) {
    if (!_gridMode || !payload.hasImages) return;
    _publish(
      moveImagesTo(_entries, payload.images, _entries.length),
      checked: const [],
    );
  }

  _DragPayload _payloadFor(PrintEntry entry) {
    if (_checked.length > 1 && _checked.contains(entry)) {
      return _DragPayload.entries(_checkedEntries);
    }
    return _DragPayload.entries([entry]);
  }

  static const _imageExtensions = {
    'jpg',
    'jpeg',
    'png',
    'gif',
    'bmp',
    'webp',
    'tif',
    'tiff',
    'heic',
    'heif',
  };

  bool _isImageItem(DropItem item) {
    final mime = item.mimeType?.toLowerCase();
    if (mime != null && mime.startsWith('image/')) return true;
    final dot = item.name.lastIndexOf('.');
    if (dot < 0 || dot == item.name.length - 1) return false;
    return _imageExtensions.contains(
      item.name.substring(dot + 1).toLowerCase(),
    );
  }

  Future<void> _handleDrop(DropDoneDetails details) async {
    setState(() => _dropActive = false);
    final loaded = <SelectedImage>[];
    for (final item in details.files) {
      if (item is DropItemDirectory) continue;
      if (!_isImageItem(item)) continue;
      try {
        final image = await _loadImageBytes(
          item.name,
          await item.readAsBytes(),
        );
        if (image != null) loaded.add(image);
      } catch (_) {}
    }
    if (!mounted) return;
    if (loaded.isNotEmpty) {
      _publish([..._entries, for (final image in loaded) ImageEntry(image)]);
    } else {
      _showMessage('No readable image files were dropped.');
    }
  }

  Future<void> _print() async {
    if (_entries.isEmpty || _printing) return;
    setState(() => _printing = true);
    try {
      final entries = List<PrintEntry>.of(_entries);
      final settings = _settings;
      final printed = await Printing.layoutPdf(
        name: 'cetakeero',
        format: PdfPageFormat(
          mmToPoints(settings.widthMm),
          mmToPoints(settings.heightMm),
          marginAll: mmToPoints(settings.marginMm),
        ),
        onLayout: (format) async {
          final document = buildPrintDocument(
            pages: [
              for (final entry in entries)
                switch (entry) {
                  ImageEntry(:final image) => PrintSingleSource(
                    image.printImage,
                  ),
                  GridEntry(
                    :final images,
                    :final rows,
                    :final cols,
                    :final gapMm,
                  ) =>
                    PrintGridSource(
                      images: [for (final image in images) image.printImage],
                      rows: rows,
                      cols: cols,
                      gapMm: gapMm,
                    ),
                },
            ],
            settings: settings,
            format: format,
          );
          return document.save();
        },
      );
      if (printed && mounted) {
        _showMessage('Sent ${entries.length} page(s) to the printer.');
      }
    } catch (error) {
      if (mounted) _showMessage('Printing failed: $error');
    } finally {
      if (mounted) setState(() => _printing = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    for (final entry in _entries) {
      for (final image in entry.images) {
        image.preview.dispose();
      }
    }
    _imagesScroll.dispose();
    _settingsScroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('cetakeero'),
        actions: [
          ThemePickerButton(
            current: widget.currentTheme,
            onChanged: widget.onThemeChanged,
          ),
          IconButton(
            tooltip: 'GitHub',
            onPressed: () async {
              await goToWebPage("https://github.com/w3teal/cetakeero");
            },
            icon: SvgPicture.string(
              gitHubSvg,
              colorFilter: ColorFilter.mode(
                Theme.of(context)
                    .colorScheme
                    .onSurfaceVariant, // Proper way to get the theme color
                BlendMode.srcIn,
              ),
              width: 24.0,
              height: 24.0,
            ),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 900;
                  final imagesPanel = _imagesPanel(context);
                  final settingsPanel = _settingsPanel(context);
                  if (!wide) {
                    return Column(
                      children: [
                        Expanded(flex: 3, child: imagesPanel),
                        const SizedBox(height: 16),
                        Expanded(flex: 2, child: settingsPanel),
                      ],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(flex: 3, child: imagesPanel),
                      const SizedBox(width: 16),
                      Expanded(flex: 2, child: settingsPanel),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _imagesPanel(BuildContext context) {
    final theme = Theme.of(context);
    return DropTarget(
      onDragEntered: (_) => setState(() => _dropActive = true),
      onDragExited: (_) => setState(() => _dropActive = false),
      onDragDone: _handleDrop,
      child: Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 8, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Images', style: theme.textTheme.titleMedium),
                            Text(
                              _entries.isEmpty
                                  ? '0 pages'
                                  : '${_entries.length} page'
                                        '${_entries.length == 1 ? '' : 's'}',
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      if (_entries.isNotEmpty)
                        TextButton(
                          onPressed: _clearAll,
                          child: const Text('Clear all'),
                        ),
                    ],
                  ),
                ),
                if (_entries.isEmpty)
                  Expanded(child: _emptyState(context))
                else ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                    child: Row(
                      children: [
                        Icon(Icons.zoom_in, size: 18, color: theme.hintColor),
                        Expanded(
                          child: Slider(
                            min: 60,
                            max: 300,
                            divisions: 28,
                            label: '${_thumbSize.round()} px',
                            value: _thumbSize,
                            onChanged: (value) {
                              setState(() => _thumbSize = value);
                            },
                          ),
                        ),
                        SizedBox(
                          width: 40,
                          child: Text(
                            '${_thumbSize.round()}',
                            textAlign: TextAlign.right,
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                    child: _selectionToolbar(context),
                  ),
                  Expanded(
                    child: DragTarget<_DragPayload>(
                      onWillAcceptWithDetails: (details) =>
                          _canDropEmptyArea(details.data),
                      onAcceptWithDetails: (details) =>
                          _dropEmptyArea(details.data),
                      builder: (context, candidates, rejected) => Scrollbar(
                        controller: _imagesScroll,
                        child: SingleChildScrollView(
                          controller: _imagesScroll,
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                          child: Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            crossAxisAlignment: WrapCrossAlignment.start,
                            children: [
                              for (var i = 0; i < _entries.length; i++)
                                _draggableEntry(context, i),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: OutlinedButton.icon(
                      onPressed: _picking ? null : _addImages,
                      icon: _picking
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.add_photo_alternate_outlined),
                      label: const Text('Add more images'),
                    ),
                  ),
                ],
              ],
            ),
            if (_dropActive)
              Positioned.fill(
                child: IgnorePointer(
                  child: ColoredBox(
                    color: theme.colorScheme.primary.withValues(alpha: 0.12),
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.inverseSurface,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.add_photo_alternate_outlined,
                              color: theme.colorScheme.onInverseSurface,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Drop images to add',
                              style: theme.textTheme.titleSmall?.copyWith(
                                color: theme.colorScheme.onInverseSurface,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _selectionToolbar(BuildContext context) {
    final theme = Theme.of(context);
    final active = _activeGrid;
    final allChecked =
        _entries.isNotEmpty && _checked.length == _entries.length;
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        IconButton(
          tooltip: allChecked ? 'Deselect all' : 'Select all',
          onPressed: _entries.isEmpty
              ? null
              : () {
                  setState(() {
                    if (allChecked) {
                      _checked.clear();
                    } else {
                      _checked.addAll(_entries);
                    }
                  });
                },
          icon: Icon(allChecked ? Icons.deselect : Icons.select_all),
          visualDensity: VisualDensity.compact,
        ),
        IconButton(
          tooltip: _gridMode
              ? 'Grid drag mode: re-sort cells, drag images between grids or out to pages. Tap to drag whole pages.'
              : 'Page drag mode: drag whole pages to reorder. Tap to drag images inside grids.',
          isSelected: _gridMode,
          onPressed: _entries.isEmpty
              ? null
              : () {
                  setState(() {
                    _gridMode = !_gridMode;
                    _checked.clear();
                  });
                },
          icon: Icon(_gridMode ? Icons.grid_on : Icons.drag_indicator),
          visualDensity: VisualDensity.compact,
        ),
        IconButton(
          tooltip: _checked.isEmpty ? 'Select images first' : 'Delete selected',
          onPressed: _checked.isEmpty ? null : _deleteChecked,
          icon: const Icon(Icons.delete_outline),
          visualDensity: VisualDensity.compact,
        ),
        IconButton(
          tooltip: _canAddToGrid
              ? 'Group selected images into a grid'
              : 'Group selected images into a grid',
          onPressed: _canAddToGrid ? _addToGrid : null,
          icon: const Icon(Icons.grid_on_outlined),
          visualDensity: VisualDensity.compact,
        ),
        if (active != null) ...[
          const SizedBox(width: 4),
          Text('Grid', style: theme.textTheme.bodySmall),
          _dimDropdown(
            active.rows,
            (rows) => _setGridDimensions(active, rows: rows),
          ),
          Text(' × ', style: theme.textTheme.bodySmall),
          _dimDropdown(
            active.cols,
            (cols) => _setGridDimensions(active, cols: cols),
          ),
          Text(
            ' ${active.images.length} img',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(width: 4),
          SizedBox(
            width: 96,
            child: Slider(
              min: 0,
              max: 12,
              divisions: 12,
              label: 'Gap ${active.gapMm.round()} mm',
              value: active.gapMm.clamp(0, 12),
              onChanged: (value) => _setGridGap(active, value),
            ),
          ),
          SizedBox(
            width: 34,
            child: Text(
              '${active.gapMm.round()} mm',
              textAlign: TextAlign.left,
              style: theme.textTheme.bodySmall,
            ),
          ),
          IconButton(
            tooltip: 'Ungroup into separate pages',
            onPressed: _ungroupGrid,
            icon: const Icon(Icons.grid_off),
            visualDensity: VisualDensity.compact,
          ),
        ],
        if (_checked.isEmpty && !_gridMode)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              'Check images to select',
              style: theme.textTheme.bodySmall,
            ),
          ),
      ],
    );
  }

  Widget _dimDropdown(int value, ValueChanged<int> onChanged) {
    return DropdownButton<int>(
      value: value,
      isDense: true,
      items: [
        for (var n = 1; n <= 6; n++)
          DropdownMenuItem(value: n, child: Text('$n')),
      ],
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
  }

  Widget _emptyState(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.photo_library_outlined,
          size: 72,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(height: 12),
        Text(
          'Choose one or more images to print',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _picking ? null : _addImages,
          icon: _picking
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.add_photo_alternate_outlined),
          label: const Text('Choose images'),
        ),
      ],
    );
  }

  Widget _draggableEntry(BuildContext context, int index) {
    final entry = _entries[index];
    final payload = _payloadFor(entry);
    return DragTarget<_DragPayload>(
      onWillAcceptWithDetails: (details) => _canDrop(details.data, entry),
      onAcceptWithDetails: (details) => _dropInto(details.data, index, entry),
      builder: (context, candidates, rejected) {
        final highlighted = _checked.contains(entry) || candidates.isNotEmpty;
        final thumb = _entryThumb(context, entry, highlighted: highlighted);
        // In grid mode the cells of a grid are the drag sources: the whole
        // page must not even own a drag recognizer, or its delayed recognizer
        // wins the gesture arena and swallows the cells' long-press.
        if (_gridMode && entry is GridEntry) return thumb;
        return LongPressDraggable<_DragPayload>(
          data: payload,
          feedback: _dragFeedback(context, payload),
          childWhenDragging: Opacity(opacity: 0.35, child: thumb),
          child: thumb,
        );
      },
    );
  }

  /// The translucent drag preview shown while reordering, with a count badge.
  Widget _dragFeedback(BuildContext context, _DragPayload payload) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final count = payload.hasEntries
        ? payload.entries.length
        : payload.images.length;
    final Widget body;
    if (payload.hasEntries) {
      body = _entryBody(context, payload.entries.first, width: 90);
    } else if (payload.images.isNotEmpty) {
      body = ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: PagePreview(
          image: payload.images.first.preview,
          settings: _settings,
          width: 90,
        ),
      );
    } else {
      body = const SizedBox(width: 90, height: 60);
    }
    return Material(
      color: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      elevation: 8,
      child: Stack(
        children: [
          body,
          Positioned(
            right: 0,
            top: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: colorScheme.inverseSurface,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colorScheme.onInverseSurface,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _entryThumb(
    BuildContext context,
    PrintEntry entry, {
    required bool highlighted,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final checked = _checked.contains(entry);
    return Container(
      foregroundDecoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: highlighted ? colorScheme.primary : Colors.transparent,
          width: highlighted ? 3 : 1,
        ),
      ),
      child: Stack(
        children: [
          _entryBody(context, entry, width: _thumbSize),
          if (!_gridMode) ...[
            if (entry is GridEntry)
              Positioned(
                bottom: 4,
                left: 4,
                child: _pill(
                  theme,
                  '${entry.rows}×${entry.cols}',
                  color: colorScheme.inverseSurface.withValues(alpha: 0.85),
                  textColor: colorScheme.onInverseSurface,
                ),
              ),
            Positioned(
              top: 4,
              left: 4,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: colorScheme.surface.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Checkbox(
                  value: checked,
                  onChanged: (_) => _toggleChecked(entry),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ),
            Positioned(
              top: 4,
              right: 4,
              child: IconButton.filledTonal(
                tooltip: 'Remove',
                iconSize: 16,
                visualDensity: VisualDensity.compact,
                onPressed: () => _removeEntry(entry),
                icon: const Icon(Icons.close),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _entryBody(
    BuildContext context,
    PrintEntry entry, {
    required double width,
  }) {
    return switch (entry) {
      ImageEntry(:final image) => ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: PagePreview(
          image: image.preview,
          settings: _settings,
          width: width,
        ),
      ),
      GridEntry(:final images, :final rows, :final cols, :final gapMm) =>
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: GridPreview(
            images: [for (final image in images) image.preview],
            rows: rows,
            cols: cols,
            gapMm: gapMm,
            settings: _settings,
            width: width,
            cellOverlayBuilder: (index, cell) {
              if (index < images.length) {
                return _gridCell(entry, images[index], index);
              }
              // Unused cells are still drop targets in grid mode, so images
              // can be dropped onto them to be added to the grid.
              if (_gridMode) return _emptyCellTarget(entry, index);
              return const SizedBox();
            },
          ),
        ),
    };
  }

  /// A grid cell: a long-press drag source for the image it holds, and a drop
  /// target in grid mode (re-sort, move between grids, insert pages).
  Widget _gridCell(GridEntry grid, SelectedImage image, int cellIndex) {
    final payload = _DragPayload.images([image]);
    final draggable = LongPressDraggable<_DragPayload>(
      data: payload,
      maxSimultaneousDrags: _gridMode ? 1 : 0,
      feedback: Material(
        color: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        elevation: 8,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: PagePreview(
            image: image.preview,
            settings: _settings,
            width: 90,
          ),
        ),
      ),
      childWhenDragging: const SizedBox(),
      child: const SizedBox.expand(
        child: ColoredBox(color: Colors.transparent),
      ),
    );
    return DragTarget<_DragPayload>(
      onWillAcceptWithDetails: (details) =>
          _canDropCell(details.data, grid, cellIndex),
      onAcceptWithDetails: (details) =>
          _dropOnCell(details.data, grid, cellIndex),
      builder: (context, candidates, rejected) => draggable,
    );
  }

  /// An unused cell: accepts drops in grid mode so images can be appended.
  Widget _emptyCellTarget(GridEntry grid, int cellIndex) {
    return DragTarget<_DragPayload>(
      onWillAcceptWithDetails: (details) =>
          _canDropCell(details.data, grid, cellIndex),
      onAcceptWithDetails: (details) =>
          _dropOnCell(details.data, grid, cellIndex),
      builder: (context, candidates, rejected) => const SizedBox.expand(),
    );
  }

  Widget _pill(
    ThemeData theme,
    String text, {
    required Color color,
    required Color textColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: theme.textTheme.labelSmall?.copyWith(color: textColor),
      ),
    );
  }

  Widget _settingsPanel(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Text(
              'Page & image settings',
              style: theme.textTheme.titleMedium,
            ),
          ),
          Expanded(
            child: Scrollbar(
              controller: _settingsScroll,
              child: ListView(
                controller: _settingsScroll,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                children: [
                  _pageSizeControl(theme),
                  const SizedBox(height: 16),
                  _orientationControl(theme),
                  const SizedBox(height: 16),
                  _fitControl(theme),
                  const SizedBox(height: 16),
                  _marginControl(theme),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: _buildPrintButton(context),
          ),
        ],
      ),
    );
  }

  Widget _pageSizeControl(ThemeData theme) {
    return DropdownMenu<PaperSize>(
      width: double.infinity,
      initialSelection: _settings.paperSize,
      label: const Text('Page size'),
      dropdownMenuEntries: [
        for (final size in PaperSize.values)
          DropdownMenuEntry(
            value: size,
            label:
                '${size.label} (${size.shortSideMm.toStringAsFixed(0)}×${size.longSideMm.toStringAsFixed(0)} mm)',
          ),
      ],
      onSelected: (size) {
        if (size != null) {
          setState(() {
            _settings = _settings.copyWith(paperSize: size);
          });
        }
      },
    );
  }

  Widget _orientationControl(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Orientation', style: theme.textTheme.bodySmall),
        const SizedBox(height: 6),
        SegmentedButton<PageOrientation>(
          segments: const [
            ButtonSegment(
              value: PageOrientation.portrait,
              label: Text('Portrait'),
              icon: Icon(Icons.personal_video_outlined),
            ),
            ButtonSegment(
              value: PageOrientation.landscape,
              label: Text('Landscape'),
              icon: Icon(Icons.personal_video),
            ),
          ],
          selected: {_settings.orientation},
          onSelectionChanged: (selection) {
            setState(() {
              _settings = _settings.copyWith(orientation: selection.first);
            });
          },
        ),
      ],
    );
  }

  Widget _fitControl(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Image fit', style: theme.textTheme.bodySmall),
        const SizedBox(height: 6),
        SegmentedButton<ImageFit>(
          segments: [
            for (final fit in ImageFit.values)
              ButtonSegment(
                value: fit,
                label: Text(fit.label),
                icon: Icon(
                  fit == ImageFit.contain
                      ? Icons.fit_screen_outlined
                      : Icons.crop,
                ),
              ),
          ],
          selected: {_settings.fit},
          onSelectionChanged: (selection) {
            setState(() {
              _settings = _settings.copyWith(fit: selection.first);
            });
          },
        ),
        const SizedBox(height: 4),
        Text(_settings.fit.description, style: theme.textTheme.bodySmall),
      ],
    );
  }

  Widget _marginControl(ThemeData theme) {
    return Row(
      children: [
        Text('Margin', style: theme.textTheme.bodyMedium),
        Expanded(
          child: Slider(
            min: 1,
            max: 50,
            divisions: 49,
            label: '${_settings.marginMm.round()} mm',
            value: _settings.marginMm,
            onChanged: (value) {
              setState(() {
                _settings = _settings.copyWith(marginMm: value);
              });
            },
          ),
        ),
        SizedBox(
          width: 52,
          child: Text(
            '${_settings.marginMm.toStringAsFixed(0)} mm',
            textAlign: TextAlign.right,
            style: theme.textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }

  Widget _buildPrintButton(BuildContext context) {
    final count = _entries.length;
    return FilledButton.icon(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(56),
        textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
      ),
      onPressed: count > 0 && !_printing ? _print : null,
      icon: _printing
          ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 3),
            )
          : const Icon(Icons.print, size: 26),
      label: Text(
        count == 0
            ? 'Add images to print'
            : _printing
            ? 'Sending to printer…'
            : 'Print $count page${count == 1 ? '' : 's'}',
      ),
    );
  }
}
