import 'package:flutter/material.dart';

/// Password reset dialog. The host performs the request and supplies localized text.
class NeoForgotPasswordDialog extends StatefulWidget {
  const NeoForgotPasswordDialog({
    super.key,
    required this.initialAccount,
    required this.title,
    required this.description,
    required this.accountLabel,
    required this.emptyError,
    required this.cancelLabel,
    required this.submitLabel,
    required this.onSubmit,
    required this.errorBuilder,
    required this.backgroundColor,
    required this.textColor,
  });
  final String initialAccount,
      title,
      description,
      accountLabel,
      emptyError,
      cancelLabel,
      submitLabel;
  final Future<bool> Function(String account) onSubmit;
  final Widget Function(String) errorBuilder;
  final Color backgroundColor, textColor;

  @override
  State<NeoForgotPasswordDialog> createState() =>
      _NeoForgotPasswordDialogState();
}

class _NeoForgotPasswordDialogState extends State<NeoForgotPasswordDialog> {
  late final TextEditingController account;
  String? error;
  bool busy = false;
  @override
  void initState() {
    super.initState();
    account = TextEditingController(text: widget.initialAccount);
  }

  @override
  void dispose() {
    account.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    final value = account.text.trim();
    if (value.isEmpty) {
      setState(() => error = widget.emptyError);
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final sent = await widget.onSubmit(value);
      if (mounted && sent) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    backgroundColor: widget.backgroundColor,
    title: Text(widget.title),
    content: SizedBox(
      width: 420,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.description,
            style: TextStyle(color: widget.textColor, height: 1.45),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: account,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(labelText: widget.accountLabel),
          ),
          if (error != null) ...[
            const SizedBox(height: 12),
            widget.errorBuilder(error!),
          ],
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: busy ? null : () => Navigator.of(context).pop(),
        child: Text(widget.cancelLabel),
      ),
      FilledButton(
        onPressed: busy ? null : submit,
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
