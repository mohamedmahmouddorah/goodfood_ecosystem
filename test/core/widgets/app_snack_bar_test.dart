import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goodfood_ecosystem/core/widgets/app_snack_bar.dart';

void main() {
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
