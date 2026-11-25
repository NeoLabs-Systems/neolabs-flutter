import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neolabs_flutter/neolabs_flutter.dart';

void main() {
  testWidgets('settings adapts between the rail and the compact page', (
    tester,
  ) async {
    Widget layout(bool showNav) => MaterialApp(
      home: Scaffold(
        body: NeoSettingsLayout(
          navigation: const Text('navigation'),
          content: const Text('content'),
          showNavigationOnCompact: showNav,
          railColor: Colors.black,
          borderColor: Colors.white,
        ),
      ),
    );
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1000, 700);
    await tester.pumpWidget(layout(false));
    expect(find.text('navigation'), findsOneWidget);
    expect(find.text('content'), findsOneWidget);
    tester.view.physicalSize = const Size(400, 700);
    await tester.pumpWidget(layout(false));
    expect(find.text('navigation'), findsNothing);
    expect(find.text('content'), findsOneWidget);
    await tester.pumpWidget(layout(true));
    expect(find.text('navigation'), findsOneWidget);
    expect(find.text('content'), findsNothing);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  });
}
