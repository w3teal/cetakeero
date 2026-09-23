import 'package:flutter/foundation.dart';

/// ISO paper sizes, from A0 down to A4.
enum PaperSize {
  a0,
  a1,
  a2,
  a3,
  a4,
}

extension PaperSizeDetails on PaperSize {
  String get label => switch (this) {
        PaperSize.a0 => 'A0',
        PaperSize.a1 => 'A1',
        PaperSize.a2 => 'A2',
        PaperSize.a3 => 'A3',
        PaperSize.a4 => 'A4',
      };

  /// Short side of the sheet in millimeters.
  double get shortSideMm => switch (this) {
        PaperSize.a0 => 841,
        PaperSize.a1 => 594,
        PaperSize.a2 => 420,
        PaperSize.a3 => 297,
        PaperSize.a4 => 210,
      };

  /// Long side of the sheet in millimeters.
  double get longSideMm => switch (this) {
        PaperSize.a0 => 1189,
        PaperSize.a1 => 841,
        PaperSize.a2 => 594,
        PaperSize.a3 => 420,
        PaperSize.a4 => 297,
      };
}

enum PageOrientation {
  portrait,
  landscape,
}

extension PageOrientationDetails on PageOrientation {
  String get label => switch (this) {
        PageOrientation.portrait => 'Portrait',
        PageOrientation.landscape => 'Landscape',
      };
}

/// How the image is placed inside the printable area.
enum ImageFit {
  /// The whole image is visible, scaled to fit inside the page.
  contain,

  /// The image fills the printable area, cropping the edges.
  cover,
}

extension ImageFitDetails on ImageFit {
  String get label => switch (this) {
        ImageFit.contain => 'Contain',
        ImageFit.cover => 'Cover',
      };

  String get description => switch (this) {
        ImageFit.contain => 'Whole image visible',
        ImageFit.cover => 'Fill page, crop edges',
      };
}

/// Full print configuration for a print job.
@immutable
class PrintSettings {
  const PrintSettings({
    this.paperSize = PaperSize.a4,
    this.orientation = PageOrientation.portrait,
    this.fit = ImageFit.contain,
    this.marginMm = 10,
  });

  final PaperSize paperSize;
  final PageOrientation orientation;
  final ImageFit fit;

  /// Page margin in millimeters, 1-50.
  final double marginMm;

  /// Sheet width in millimeters for the selected orientation.
  double get widthMm => orientation == PageOrientation.portrait
      ? paperSize.shortSideMm
      : paperSize.longSideMm;

  /// Sheet height in millimeters for the selected orientation.
  double get heightMm => orientation == PageOrientation.portrait
      ? paperSize.longSideMm
      : paperSize.shortSideMm;

  PrintSettings copyWith({
    PaperSize? paperSize,
    PageOrientation? orientation,
    ImageFit? fit,
    double? marginMm,
  }) {
    return PrintSettings(
      paperSize: paperSize ?? this.paperSize,
      orientation: orientation ?? this.orientation,
      fit: fit ?? this.fit,
      marginMm: marginMm ?? this.marginMm,
    );
  }
}