import 'package:catppuccin_flutter/catppuccin_flutter.dart';
import 'package:flutter/material.dart';

/// A catppuccin flavor and the accent color picked from it.
typedef ThemeSelection = ({Flavor flavor, Color accent});

/// The theme used on first launch: latte with a mauve accent.
final ThemeSelection defaultThemeSelection = (
  flavor: catppuccin.latte,
  accent: catppuccin.latte.mauve,
);

/// Keys `shared_preferences` entries used to persist the theme.
const String themeFlavorKey = 'theme.flavor';
const String themeAccentKey = 'theme.accent';

/// The accent colors a [Flavor] offers, in display order.
typedef AccentColor = ({String label, Color Function(Flavor flavor) color});

List<AccentColor> get accentColors => const [
      (label: 'Rosewater', color: _rosewater),
      (label: 'Flamingo', color: _flamingo),
      (label: 'Pink', color: _pink),
      (label: 'Mauve', color: _mauve),
      (label: 'Red', color: _red),
      (label: 'Maroon', color: _maroon),
      (label: 'Peach', color: _peach),
      (label: 'Yellow', color: _yellow),
      (label: 'Green', color: _green),
      (label: 'Teal', color: _teal),
      (label: 'Sky', color: _sky),
      (label: 'Sapphire', color: _sapphire),
      (label: 'Blue', color: _blue),
      (label: 'Lavender', color: _lavender),
    ];

Color _rosewater(Flavor f) => f.rosewater;
Color _flamingo(Flavor f) => f.flamingo;
Color _pink(Flavor f) => f.pink;
Color _mauve(Flavor f) => f.mauve;
Color _red(Flavor f) => f.red;
Color _maroon(Flavor f) => f.maroon;
Color _peach(Flavor f) => f.peach;
Color _yellow(Flavor f) => f.yellow;
Color _green(Flavor f) => f.green;
Color _teal(Flavor f) => f.teal;
Color _sky(Flavor f) => f.sky;
Color _sapphire(Flavor f) => f.sapphire;
Color _blue(Flavor f) => f.blue;
Color _lavender(Flavor f) => f.lavender;

/// The label of [accent] within [accentColors], or null when not present.
String? accentLabel(Flavor flavor, Color accent) {
  for (final accentColor in accentColors) {
    if (accentColor.color(flavor) == accent) {
      return accentColor.label;
    }
  }
  return null;
}

/// Rebuilds [ThemeData] for the given [Flavor] and accent color. Latte maps
/// to light brightness, every other flavor to dark.
ThemeData themeDataFor(Flavor flavor, Color accent) {
  final brightness =
      flavor == catppuccin.latte ? Brightness.light : Brightness.dark;
  final scheme = ColorScheme.fromSeed(
    seedColor: accent,
    brightness: brightness,
  ).copyWith(
    primary: accent,
    secondary: flavor.teal,
    tertiary: flavor.lavender,
    surface: flavor.base,
    onSurface: flavor.text,
    surfaceContainerLowest: flavor.mantle,
    surfaceContainerLow: flavor.crust,
    surfaceContainer: flavor.surface0,
    surfaceContainerHigh: flavor.surface1,
    surfaceContainerHighest: flavor.surface2,
    onSurfaceVariant: flavor.overlay1,
    outline: flavor.overlay1,
    outlineVariant: flavor.overlay2,
    scrim: flavor.crust,
  );
  return ThemeData(colorScheme: scheme);
}

/// Stored name of a flavor, e.g. `"latte"`.
String flavorName(Flavor flavor) {
  if (flavor == catppuccin.latte) return 'latte';
  if (flavor == catppuccin.frappe) return 'frappe';
  if (flavor == catppuccin.macchiato) return 'macchiato';
  return 'mocha';
}

Flavor flavorByName(String? name) {
  return switch (name) {
    'frappe' => catppuccin.frappe,
    'macchiato' => catppuccin.macchiato,
    'mocha' => catppuccin.mocha,
    _ => catppuccin.latte,
  };
}

Color accentByName(Flavor flavor, String? name) {
  if (name == null) return flavor.mauve;
  for (final accentColor in accentColors) {
    if (accentColor.label.toLowerCase() == name.toLowerCase()) {
      return accentColor.color(flavor);
    }
  }
  return flavor.mauve;
}