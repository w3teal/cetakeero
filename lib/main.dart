import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'src/models/theme_selection.dart';
import 'src/screens/home_screen.dart';

void main() {
  runApp(const CetakeeroApp());
}

class CetakeeroApp extends StatefulWidget {
  const CetakeeroApp({super.key});

  @override
  State<CetakeeroApp> createState() => _CetakeeroAppState();
}

class _CetakeeroAppState extends State<CetakeeroApp> {
  ThemeSelection _selection = defaultThemeSelection;

  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final flavor = flavorByName(prefs.getString(themeFlavorKey));
    setState(() {
      _selection = (
        flavor: flavor,
        accent: accentByName(flavor, prefs.getString(themeAccentKey)),
      );
    });
  }

  void _setTheme(ThemeSelection selection) {
    setState(() => _selection = selection);
    SharedPreferences.getInstance().then((prefs) {
      prefs.setString(themeFlavorKey, flavorName(selection.flavor));
      final accent = accentLabel(selection.flavor, selection.accent);
      if (accent != null) {
        prefs.setString(themeAccentKey, accent.toLowerCase());
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'cetakeero',
      debugShowCheckedModeBanner: false,
      theme: themeDataFor(_selection.flavor, _selection.accent),
      home: HomeScreen(
        currentTheme: _selection,
        onThemeChanged: _setTheme,
      ),
    );
  }
}