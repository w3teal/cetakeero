import 'package:catppuccin_flutter/catppuccin_flutter.dart';
import 'package:flutter/material.dart';

import '../models/theme_selection.dart';

/// An AppBar `Theme` menu button. It opens a menu with one submenu per
/// catppuccin flavor; each submenu lists the flavor's 14 accent colors.
class ThemePickerButton extends StatelessWidget {
  const ThemePickerButton({
    super.key,
    required this.current,
    required this.onChanged,
  });

  /// The currently active flavor + accent, used for check marks.
  final ThemeSelection current;

  /// Called with the new selection when the user picks a color.
  final ValueChanged<ThemeSelection> onChanged;

  @override
  Widget build(BuildContext context) {
    final controller = MenuController();
    return MenuAnchor(
      controller: controller,
      alignmentOffset: const Offset(0, 8),
      menuChildren: [
        for (final flavor in _flavors)
          _flavorSubmenu(controller, flavor),
      ],
      builder: (context, menuController, child) {
        return IconButton(
          tooltip: 'Theme',
          onPressed: () {
            if (menuController.isOpen) {
              menuController.close();
            } else {
              menuController.open();
            }
          },
          icon: const Icon(Icons.palette_outlined),
        );
      },
    );
  }

  Widget _flavorSubmenu(MenuController menuController, Flavor flavor) {
    final name = flavorName(flavor);
    final isCurrentFlavor = flavor == current.flavor;
    return SubmenuButton(
      menuChildren: [
        for (final accent in accentColors)
          _accentItem(menuController, flavor, accent),
      ],
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isCurrentFlavor) const Icon(Icons.check),
          const SizedBox(width: 8),
          Text(name[0].toUpperCase() + name.substring(1)),
        ],
      ),
    );
  }

  Widget _accentItem(
    MenuController menuController,
    Flavor flavor,
    AccentColor accent,
  ) {
    final color = accent.color(flavor);
    final isSelected = flavor == current.flavor && color == current.accent;
    return MenuItemButton(
      onPressed: () {
        onChanged((flavor: flavor, accent: color));
        menuController.close();
      },
      leadingIcon: _colorDot(color),
      trailingIcon: isSelected ? const Icon(Icons.check) : null,
      child: Text(accent.label),
    );
  }

  Widget _colorDot(Color color) {
    return Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

final List<Flavor> _flavors = [
  catppuccin.latte,
  catppuccin.frappe,
  catppuccin.macchiato,
  catppuccin.mocha,
];