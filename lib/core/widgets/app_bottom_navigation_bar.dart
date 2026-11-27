import 'package:flutter/material.dart';
import '../localization/goodfood_localizations.dart';

class AppNavigationItem {
  const AppNavigationItem({
    required this.label,
    required this.icon,
    this.selectedIcon,
    this.onTap,
  });

  final String label;
  final IconData icon;
  final IconData? selectedIcon;
  final VoidCallback? onTap;
}

class AppBottomNavigationBar extends StatelessWidget {
  const AppBottomNavigationBar({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onDestinationSelected,
    this.backgroundColor,
    this.indicatorColor,
    this.selectedColor,
    this.unselectedColor,
    this.height = 64,
    this.maxWidth = 1100,
  }) : assert(items.length >= 2),
       assert(selectedIndex >= 0 && selectedIndex < items.length);

  final List<AppNavigationItem> items;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final Color? backgroundColor;
  final Color? indicatorColor;
  final Color? selectedColor;
  final Color? unselectedColor;
  final double height;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    return SizedBox(
      height: height + safeBottom,
      child: SafeArea(
        top: false,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: backgroundColor,
            border: Border(top: BorderSide(color: colorScheme.outlineVariant)),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 800;
              final showLabels = constraints.maxWidth >= 320;
              return Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxWidth),
                  child: NavigationBar(
                    height: height,
                    selectedIndex: selectedIndex,
                    backgroundColor: backgroundColor,
                    indicatorColor: indicatorColor,
                    labelTextStyle: WidgetStateProperty.resolveWith(
                      (states) => TextStyle(
                        fontSize: 11,
                        height: 1.2,
                        fontWeight: states.contains(WidgetState.selected)
                            ? FontWeight.w600
                            : FontWeight.w400,
                        color: states.contains(WidgetState.selected)
                            ? selectedColor
                            : unselectedColor,
                      ),
                    ),
                    labelBehavior: showLabels
                        ? NavigationDestinationLabelBehavior.alwaysShow
                        : NavigationDestinationLabelBehavior.onlyShowSelected,
                    destinations: [
                      for (final item in items)
                        NavigationDestination(
                          icon: Icon(
                            item.icon,
                            color: unselectedColor,
                            size: isWide ? 25 : 20,
                          ),
                          selectedIcon: Icon(
                            item.selectedIcon ?? item.icon,
                            color: selectedColor,
                            size: isWide ? 25 : 20,
                          ),
                          label: context.tr(item.label),
                          tooltip: context.tr(item.label),
                        ),
                    ],
                    onDestinationSelected: (index) {
                      final onTap = items[index].onTap;
                      if (onTap != null) {
                        onTap();
                      } else {
                        onDestinationSelected(index);
                      }
                    },
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Side navigation for wide layouts. Phones continue using [AppBottomNavigationBar].
class AppNavigationRail extends StatelessWidget {
  const AppNavigationRail({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onDestinationSelected,
    this.backgroundColor,
    this.indicatorColor,
    this.selectedColor,
    this.unselectedColor,
    this.width = 260,
  });

  final List<AppNavigationItem> items;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final Color? backgroundColor;
  final Color? indicatorColor;
  final Color? selectedColor;
  final Color? unselectedColor;
  final double width;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: width,
      height: double.infinity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: backgroundColor,
          border: BorderDirectional(
            end: BorderSide(color: scheme.outlineVariant),
          ),
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 22),
              for (var index = 0; index < items.length; index++)
                _RailItem(
                  item: items[index],
                  selected: index == selectedIndex,
                  backgroundColor: indicatorColor,
                  selectedColor: selectedColor,
                  unselectedColor: unselectedColor,
                  onTap: () {
                    final action = items[index].onTap;
                    if (action != null) {
                      action();
                    } else {
                      onDestinationSelected(index);
                    }
                  },
                ),
              const Spacer(),
              const SizedBox(height: 18),
            ],
          ),
        ),
      ),
    );
  }
}

class _RailItem extends StatelessWidget {
  const _RailItem({
    required this.item,
    required this.selected,
    required this.backgroundColor,
    required this.selectedColor,
    required this.unselectedColor,
    required this.onTap,
  });

  final AppNavigationItem item;
  final bool selected;
  final Color? backgroundColor;
  final Color? selectedColor;
  final Color? unselectedColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = selected ? selectedColor : unselectedColor;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(12, 5, 12, 5),
      child: Material(
        color: selected
            ? (backgroundColor ?? Colors.transparent)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 13, 16, 13),
            child: Row(
              children: [
                Icon(
                  selected ? (item.selectedIcon ?? item.icon) : item.icon,
                  color: foreground,
                  size: 25,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    context.tr(item.label),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: foreground,
                      fontSize: 17,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
