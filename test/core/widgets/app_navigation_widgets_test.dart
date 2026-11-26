import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goodfood_ecosystem/core/widgets/app_bottom_navigation_bar.dart';
import 'package:goodfood_ecosystem/core/widgets/app_button.dart';

void main() {
  testWidgets('app button invokes its action', (tester) async {
    var pressed = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppButton(
            onPressed: () => pressed = true,
            child: const Text('Save'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Save'));
    expect(pressed, isTrue);
  });

  testWidgets('bottom navigation reports the selected destination', (
    tester,
  ) async {
    var selectedIndex = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          bottomNavigationBar: AppBottomNavigationBar(
            items: const [
              AppNavigationItem(label: 'Home', icon: Icons.home_outlined),
              AppNavigationItem(
                label: 'Cart',
                icon: Icons.shopping_bag_outlined,
              ),
            ],
            selectedIndex: selectedIndex,
            onDestinationSelected: (index) => selectedIndex = index,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Cart'));
    expect(selectedIndex, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('bottom navigation supports a direct destination callback', (
    tester,
  ) async {
    var openedOrders = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          bottomNavigationBar: AppBottomNavigationBar(
            items: [
              const AppNavigationItem(
                label: 'Menu',
                icon: Icons.restaurant_menu_outlined,
              ),
              AppNavigationItem(
                label: 'Orders',
                icon: Icons.receipt_long_outlined,
                onTap: () => openedOrders = true,
              ),
            ],
            selectedIndex: 0,
            onDestinationSelected: (_) {},
          ),
        ),
      ),
    );

    await tester.tap(find.text('Orders'));
    expect(openedOrders, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('bottom navigation stays at the bottom without hiding the body', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: const SizedBox.expand(key: ValueKey('menu-body')),
          bottomNavigationBar: AppBottomNavigationBar(
            items: const [
              AppNavigationItem(label: 'Home', icon: Icons.home_outlined),
              AppNavigationItem(
                label: 'Orders',
                icon: Icons.receipt_long_outlined,
              ),
              AppNavigationItem(
                label: 'Menu',
                icon: Icons.restaurant_menu_outlined,
              ),
              AppNavigationItem(label: 'Profile', icon: Icons.person_outline),
            ],
            selectedIndex: 2,
            onDestinationSelected: (_) {},
          ),
        ),
      ),
    );

    final bodyRect = tester.getRect(find.byKey(const ValueKey('menu-body')));
    final navigationRect = tester.getRect(find.byType(NavigationBar));
    expect(bodyRect.height, greaterThan(600));
    expect(navigationRect.top, greaterThan(700));
    expect(tester.takeException(), isNull);
  });
}
