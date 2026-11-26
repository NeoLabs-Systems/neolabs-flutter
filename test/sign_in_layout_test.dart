import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neolabs_flutter/neolabs_flutter.dart';

void main() {
  testWidgets('the QR card shows the code inline only where it fits', (
    tester,
  ) async {
    for (final (width, inline) in <(double, bool)>[(380, true), (300, false)]) {
      final seen = <bool>[];
      var opened = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: width,
                child: NeoQrSignInCard(
                  palette: paletteFor(Brightness.light),
                  payload: null,
                  preparing: false,
                  title: 'Scan',
                  instructions: 'Open settings',
                  status: 'Waiting',
                  refreshLabel: 'New code',
                  openLabel: 'Show code',
                  onRefresh: () {},
                  onOpen: () => opened++,
                  onLayout: seen.add,
                ),
              ),
            ),
          ),
        ),
      );
      expect(seen.last, inline);
      expect(
        find.text('Open settings'),
        inline ? findsOneWidget : findsNothing,
      );
      if (!inline) {
        await tester.tap(find.text('Show code'));
        expect(opened, 1);
      }
    }
  });
}
