import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goodfood_ecosystem/core/widgets/app_snack_bar.dart';

void main() {
  for (final width in [320.0, 1280.0]) {
    testWidgets('floating feedback stays above fixed actions at $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      const bar = Key('fixed actions');
      late BuildContext screen;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            bottomNavigationBar: const SizedBox(key: bar, height: 150),
            body: Builder(
              builder: (context) {
                screen = context;
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );
      showAppSnackBar(screen, message: 'First result');
      showAppSnackBar(
        screen,
        message: 'Latest result',
        kind: FeedbackKind.error,
      );
      await tester.pumpAndSettle();
      expect(find.text('First result'), findsNothing);
      final snack = find.byType(SnackBar);
      expect(snack, findsOneWidget);
      expect(
        tester.widget<SnackBar>(snack).behavior,
        SnackBarBehavior.floating,
      );
      expect(
        tester.getBottomLeft(snack).dy,
        lessThanOrEqualTo(tester.getTopLeft(find.byKey(bar)).dy),
      );
      final surface = find
          .descendant(of: snack, matching: find.byType(Material))
          .first;
      expect(tester.getSize(surface).width, lessThanOrEqualTo(560));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('snackbar content updates immediately from its listenable', (
    tester,
  ) async {
    final message = ValueNotifier<String>('Orange juice added to your cart.');
    addTearDown(message.dispose);
    late BuildContext scaffoldContext;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              scaffoldContext = context;
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );

    showAppSnackBar(
      scaffoldContext,
      message: message.value,
      messageListenable: message,
      duration: const Duration(days: 1),
      action: SnackBarAction(label: 'View cart', onPressed: () {}),
    );
    await tester.pumpAndSettle();
    expect(find.text('Orange juice added to your cart.'), findsOneWidget);

    message.value = 'Mango juice added to your cart.';
    await tester.pump();

    expect(find.text('Mango juice added to your cart.'), findsOneWidget);
    expect(find.text('Orange juice added to your cart.'), findsNothing);
    expect(find.text('View cart'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
