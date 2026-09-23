import 'dart:ui' as ui;

import '../print/print_image.dart';

/// An image picked by the user, decoded for previews.
class SelectedImage {
  SelectedImage({required this.printImage, required this.preview});

  final PrintImage printImage;

  /// Decoded image used for on-screen thumbnails.
  final ui.Image preview;

  String get name => printImage.name;
  int get width => printImage.width;
  int get height => printImage.height;
}