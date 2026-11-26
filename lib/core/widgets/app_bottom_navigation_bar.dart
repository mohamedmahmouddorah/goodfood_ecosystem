import 'package:flutter/material.dart';

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
              final showLabels = constraints.maxWidth >= 360;
              return Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxWidth),
                  child: NavigationBar(
                    height: height,
                    selectedIndex: selectedIndex,
                    backgroundColor: backgroundColor,
                    indicatorColor: indicatorColor,
                    labelBehavior: showLabels
                        ? NavigationDestinationLabelBehavior.alwaysShow
                        : NavigationDestinationLabelBehavior.onlyShowSelected,
                    destinations: [
                      for (final item in items)
                        NavigationDestination(
                          icon: Icon(
                            item.icon,
                            color: unselectedColor,
                            size: 20,
                          ),
                          selectedIcon: Icon(
                            item.selectedIcon ?? item.icon,
                            color: selectedColor,
                            size: 20,
                          ),
                          label: item.label,
                          tooltip: item.label,
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
