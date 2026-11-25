import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neolabs_flutter/neolabs_flutter.dart';

void main() {
  testWidgets('validates the account and waits for the reset request', (
    tester,
  ) async {
    final request = Completer<bool>();
    String? submitted;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NeoForgotPasswordDialog(
            initialAccount: '',
            title: 'Reset',
            description: 'Enter account',
            accountLabel: 'Account',
            emptyError: 'Required',
            cancelLabel: 'Cancel',
            submitLabel: 'Send',
            onSubmit: (value) {
              submitted = value;
              return request.future;
            },
            errorBuilder: (message) => Text(message),
            backgroundColor: Colors.white,
            textColor: Colors.black,
          ),
        ),
      ),
    );
    await tester.tap(find.text('Send'));
    await tester.pump();
    expect(find.text('Required'), findsOneWidget);
    await tester.enterText(find.byType(TextField), ' alice ');
    await tester.tap(find.text('Send'));
    await tester.pump();
    expect(submitted, 'alice');
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(
      tester.widget<TextButton>(find.byType(TextButton)).onPressed,
      isNull,
    );
    request.complete(false);
    await tester.pump();
    expect(find.text('Send'), findsOneWidget);
  });
}
