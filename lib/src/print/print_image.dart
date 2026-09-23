import 'dart:typed_data';

/// An image selected by the user, ready to be laid out on a page.
class PrintImage {
  const PrintImage({
    required this.name,
    required this.bytes,
    required this.width,
    required this.height,
  });

  final String name;
  final Uint8List bytes;
  final int width;
  final int height;
}