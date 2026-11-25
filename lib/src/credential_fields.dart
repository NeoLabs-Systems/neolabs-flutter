import 'package:flutter/material.dart';

enum NeoCredentialField { username, email, password, confirmPassword }

/// The credential portion of a sign-in or registration form. The application
/// supplies localized labels, validation, submission and optional extra widgets.
class NeoCredentialFields extends StatelessWidget {
  const NeoCredentialFields({
    super.key,
    required this.register,
    required this.username,
    required this.email,
    required this.password,
    required this.confirmPassword,
    required this.usernameFocus,
    required this.emailFocus,
    required this.passwordFocus,
    required this.confirmPasswordFocus,
    required this.obscurePassword,
    required this.onChanged,
    required this.onSubmit,
    required this.decoration,
    required this.labeledField,
    required this.usernameLabel,
    required this.usernameOrEmailLabel,
    required this.emailLabel,
    required this.passwordLabel,
    required this.confirmPasswordLabel,
    required this.passwordToggle,
    this.forgotPassword,
    this.passwordStrength,
  });

  final bool register;
  final TextEditingController username, email, password, confirmPassword;
  final FocusNode usernameFocus,
      emailFocus,
      passwordFocus,
      confirmPasswordFocus;
  final bool obscurePassword;
  final void Function(NeoCredentialField) onChanged;
  final VoidCallback onSubmit;
  final InputDecoration Function(NeoCredentialField, Widget?) decoration;
  final Widget Function(String, Widget, Widget?) labeledField;
  final String usernameLabel,
      usernameOrEmailLabel,
      emailLabel,
      passwordLabel,
      confirmPasswordLabel;
  final Widget? passwordToggle, forgotPassword, passwordStrength;

  @override
  Widget build(BuildContext context) {
    final user = TextField(
      controller: username,
      focusNode: usernameFocus,
      autofillHints: const [AutofillHints.username],
      keyboardType: register ? TextInputType.text : TextInputType.emailAddress,
      autocorrect: false,
      enableSuggestions: false,
      textInputAction: TextInputAction.next,
      onChanged: (_) => onChanged(NeoCredentialField.username),
      onSubmitted: (_) =>
          (register ? emailFocus : passwordFocus).requestFocus(),
      decoration: decoration(NeoCredentialField.username, null),
    );
    final secret = TextField(
      controller: password,
      focusNode: passwordFocus,
      obscureText: obscurePassword,
      autocorrect: false,
      enableSuggestions: false,
      autofillHints: [
        register ? AutofillHints.newPassword : AutofillHints.password,
      ],
      textInputAction: register ? TextInputAction.next : TextInputAction.done,
      onChanged: (_) => onChanged(NeoCredentialField.password),
      onSubmitted: (_) {
        if (register) {
          confirmPasswordFocus.requestFocus();
        } else {
          onSubmit();
        }
      },
      decoration: decoration(NeoCredentialField.password, passwordToggle),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        labeledField(
          register ? usernameLabel : usernameOrEmailLabel,
          user,
          null,
        ),
        const SizedBox(height: 14),
        if (register) ...[
          labeledField(
            emailLabel,
            TextField(
              controller: email,
              focusNode: emailFocus,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              enableSuggestions: false,
              autofillHints: const [AutofillHints.email],
              textInputAction: TextInputAction.next,
              onChanged: (_) => onChanged(NeoCredentialField.email),
              onSubmitted: (_) => passwordFocus.requestFocus(),
              decoration: decoration(NeoCredentialField.email, null),
            ),
            null,
          ),
          const SizedBox(height: 14),
        ],
        labeledField(passwordLabel, secret, register ? null : forgotPassword),
        if (register) ...[
          const SizedBox(height: 10),
          if (passwordStrength != null) passwordStrength!,
          const SizedBox(height: 14),
          labeledField(
            confirmPasswordLabel,
            TextField(
              controller: confirmPassword,
              focusNode: confirmPasswordFocus,
              obscureText: obscurePassword,
              autocorrect: false,
              enableSuggestions: false,
              autofillHints: const [AutofillHints.newPassword],
              textInputAction: TextInputAction.done,
              onChanged: (_) => onChanged(NeoCredentialField.confirmPassword),
              onSubmitted: (_) => onSubmit(),
              decoration: decoration(
                NeoCredentialField.confirmPassword,
                passwordToggle,
              ),
            ),
            null,
          ),
        ],
      ],
    );
  }
}
