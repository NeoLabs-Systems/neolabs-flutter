import 'package:flutter/material.dart';

import 'account_client.dart';

/// Asks for the account's password, its 2FA code and, for destructive
/// actions, a typed phrase before a sensitive action. The host performs the
/// action in [onSubmit] and returns the refusal to show, or null when it
/// succeeded; the dialog then closes with true.
class NeoConfirmIdentityDialog extends StatefulWidget {
  const NeoConfirmIdentityDialog({
    super.key,
    required this.title,
    required this.cancelLabel,
    required this.submitLabel,
    required this.onSubmit,
    this.message,
    this.details,
    this.askPassword = true,
    this.passwordLabel = '',
    this.askCode = false,
    this.codeLabel = '',
    this.confirmPhrase,
    this.confirmLabel = '',
    this.destructive = false,
  });

  final String title, cancelLabel, submitLabel;
  final String? message;

  /// What the action does and keeps, shown above the fields.
  final Widget? details;
  final bool askPassword;
  final String passwordLabel;

  /// Shows the field for a 2FA or recovery code.
  final bool askCode;
  final String codeLabel;

  /// Text that must be typed (case and surrounding space ignored) before
  /// the action can run, such as the username.
  final String? confirmPhrase;
  final String confirmLabel;
  final bool destructive;
  final Future<String?> Function(NeoIdentity identity) onSubmit;

  /// Shows the dialog; true when the action ran.
  static Future<bool> show(
    BuildContext context,
    NeoConfirmIdentityDialog dialog,
  ) async =>
      await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => dialog,
      ) ??
      false;

  @override
  State<NeoConfirmIdentityDialog> createState() =>
      _NeoConfirmIdentityDialogState();
}

class _NeoConfirmIdentityDialogState extends State<NeoConfirmIdentityDialog> {
  final password = TextEditingController();
  final code = TextEditingController();
  final phrase = TextEditingController();
  String? error;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    for (final c in <TextEditingController>[password, code, phrase]) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    password.dispose();
    code.dispose();
    phrase.dispose();
    super.dispose();
  }

  bool get ready {
    final want = widget.confirmPhrase;
    return (!widget.askPassword || password.text.isNotEmpty) &&
        (!widget.askCode || code.text.trim().length >= 6) &&
        (want == null ||
            phrase.text.trim().toLowerCase() == want.trim().toLowerCase());
  }

  Future<void> submit() async {
    if (!ready || busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    final refusal = await widget.onSubmit(
      NeoIdentity(
        password: widget.askPassword ? password.text : '',
        code: widget.askCode ? code.text.trim() : '',
        confirmation: widget.confirmPhrase == null ? '' : phrase.text.trim(),
      ),
    );
    if (!mounted) return;
    if (refusal == null) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      busy = false;
      error = refusal;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget field(
      TextEditingController c,
      String label, {
      bool obscure = false,
      List<String> autofill = const <String>[],
    }) => Padding(
      padding: const EdgeInsets.only(top: 12),
      child: TextField(
        controller: c,
        obscureText: obscure,
        enabled: !busy,
        autofillHints: autofill,
        onSubmitted: (_) => submit(),
        decoration: InputDecoration(labelText: label),
      ),
    );
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              if (widget.message != null) Text(widget.message!),
              if (widget.details != null) ...<Widget>[
                const SizedBox(height: 12),
                widget.details!,
              ],
              if (widget.askPassword)
                field(
                  password,
                  widget.passwordLabel,
                  obscure: true,
                  autofill: const <String>[AutofillHints.password],
                ),
              if (widget.askCode)
                field(
                  code,
                  widget.codeLabel,
                  autofill: const <String>[AutofillHints.oneTimeCode],
                ),
              if (widget.confirmPhrase != null)
                field(phrase, widget.confirmLabel),
              if (error != null) ...<Widget>[
                const SizedBox(height: 12),
                Text(error!, style: TextStyle(color: scheme.error)),
              ],
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: busy ? null : () => Navigator.of(context).pop(false),
          child: Text(widget.cancelLabel),
        ),
        FilledButton(
          style: widget.destructive
              ? FilledButton.styleFrom(
                  backgroundColor: scheme.error,
                  foregroundColor: scheme.onError,
                )
              : null,
          onPressed: ready && !busy ? submit : null,
          child: busy
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(widget.submitLabel),
        ),
      ],
    );
  }
}
