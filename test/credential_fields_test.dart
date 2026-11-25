import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neolabs_flutter/neolabs_flutter.dart';

void main() {
  testWidgets(
    'sign-in and registration fields preserve input and report edits',
    (tester) async {
      final controllers = List.generate(4, (_) => TextEditingController());
      final focus = List.generate(4, (_) => FocusNode());
      addTearDown(() {
        for (final c in controllers) {
          c.dispose();
        }
        for (final f in focus) {
          f.dispose();
        }
      });
      final edits = <NeoCredentialField>[];
      var submissions = 0;
      Widget form(bool register) => MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: NeoCredentialFields(
              register: register,
              username: controllers[0],
              email: controllers[1],
              password: controllers[2],
              confirmPassword: controllers[3],
              usernameFocus: focus[0],
              emailFocus: focus[1],
              passwordFocus: focus[2],
              confirmPasswordFocus: focus[3],
              obscurePassword: true,
              onChanged: edits.add,
              onSubmit: () => submissions++,
              decoration: (_, __) => const InputDecoration(),
              labeledField: (label, field, trailing) => Column(
                children: [Text(label), field, if (trailing != null) trailing],
              ),
              usernameLabel: 'User',
              usernameOrEmailLabel: 'Account',
              emailLabel: 'Email',
              passwordLabel: 'Password',
              confirmPasswordLabel: 'Confirm',
              passwordToggle: null,
              forgotPassword: const Text('Forgot'),
              passwordStrength: const Text('Strength'),
            ),
          ),
        ),
      );
      await tester.pumpWidget(form(false));
      expect(find.byType(TextField), findsNWidgets(2));
      expect(find.text('Forgot'), findsOneWidget);
      await tester.enterText(find.byType(TextField).first, 'alice');
      expect(edits, contains(NeoCredentialField.username));
      await tester.pumpWidget(form(true));
      expect(find.byType(TextField), findsNWidgets(4));
      expect(find.text('alice'), findsOneWidget);
      expect(find.text('Strength'), findsOneWidget);
      expect(find.text('Forgot'), findsNothing);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      expect(submissions, 0);
    },
  );
}
