import 'package:flutter/material.dart';

import 'account_client.dart';
import 'confirm_identity_dialog.dart';
import 'palette.dart';
import 'settings_blocks.dart';

/// Loads and ends the account's sessions for [NeoSessionsGroup].
class NeoSessionsController extends ChangeNotifier {
  NeoSessionsController({
    required Future<List<NeoAccountSession>> Function() load,
    required Future<List<NeoAccountSession>?> Function(String id) revoke,
    Future<List<NeoAccountSession>?> Function()? signOutEverywhere,
  }) : _load = load,
       _revoke = revoke,
       _signOutEverywhere = signOutEverywhere;

  /// A controller over the shared account routes.
  factory NeoSessionsController.api(
    NeoAccountApi api, {
    bool signOutEverywhere = true,
  }) => NeoSessionsController(
    load: api.sessions,
    revoke: api.revokeSession,
    signOutEverywhere: signOutEverywhere ? api.signOutEverywhere : null,
  );

  final Future<List<NeoAccountSession>> Function() _load;
  final Future<List<NeoAccountSession>?> Function(String id) _revoke;
  final Future<List<NeoAccountSession>?> Function()? _signOutEverywhere;

  List<NeoAccountSession> sessions = const <NeoAccountSession>[];
  bool loading = false;

  /// The id being ended, or "*" while signing out everywhere.
  String? busy;
  Object? error;

  bool get canSignOutEverywhere => _signOutEverywhere != null;
  bool get hasOthers => sessions.any((s) => !s.current);

  Future<void> load() => _run(null, _load);

  Future<void> revoke(String id) =>
      _run(id, () async => await _revoke(id) ?? await _load());

  Future<void> signOutEverywhere() =>
      _run('*', () async => await _signOutEverywhere!() ?? await _load());

  Future<void> _run(
    String? id,
    Future<List<NeoAccountSession>> Function() work,
  ) async {
    if (loading || busy != null) return;
    loading = id == null;
    busy = id;
    error = null;
    notifyListeners();
    try {
      sessions = await work();
    } catch (e) {
      error = e;
    } finally {
      loading = false;
      busy = null;
      notifyListeners();
    }
  }
}

/// Wording of [NeoSessionsGroup].
class NeoSessionsTexts {
  const NeoSessionsTexts({
    required this.title,
    this.description,
    required this.currentTag,
    required this.revoke,
    required this.signOutEverywhere,
    required this.empty,
  });

  final String title, currentTag, revoke, signOutEverywhere, empty;
  final String? description;
}

/// The account's sessions on one settings card: each device with a button
/// that ends it, the current one tagged, and "sign out everywhere".
class NeoSessionsGroup extends StatefulWidget {
  const NeoSessionsGroup({
    super.key,
    required this.palette,
    required this.controller,
    required this.texts,
    required this.label,
    required this.describeError,
    this.description,
    this.confirmSignOutEverywhere,
  });

  final NeoLabsPalette palette;
  final NeoSessionsController controller;
  final NeoSessionsTexts texts;

  /// The row title of a session, such as the browser and system.
  final String Function(NeoAccountSession session) label;

  /// The row help, such as place and last activity.
  final String? Function(NeoAccountSession session)? description;
  final String Function(Object error) describeError;

  /// Asked before signing out everywhere; runs at once when null.
  final Future<bool> Function()? confirmSignOutEverywhere;

  @override
  State<NeoSessionsGroup> createState() => _NeoSessionsGroupState();
}

class _NeoSessionsGroupState extends State<NeoSessionsGroup> {
  @override
  void initState() {
    super.initState();
    widget.controller.load();
  }

  Future<void> _signOutEverywhere() async {
    final confirm = widget.confirmSignOutEverywhere;
    if (confirm != null && !await confirm()) return;
    await widget.controller.signOutEverywhere();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) {
      final c = widget.controller;
      final t = widget.texts;
      final p = widget.palette;
      final rows = <Widget>[
        if (c.loading && c.sessions.isEmpty)
          const Padding(
            padding: EdgeInsets.all(20),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          )
        else if (c.sessions.isEmpty)
          NeoSettingsRow(palette: p, label: t.empty),
        for (final s in c.sessions)
          NeoSettingsRow(
            palette: p,
            label: widget.label(s),
            description: widget.description?.call(s),
            tag: s.current ? t.currentTag : null,
            control: s.current
                ? null
                : TextButton(
                    onPressed: c.busy == null ? () => c.revoke(s.id) : null,
                    child: c.busy == s.id
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(t.revoke),
                  ),
          ),
      ];
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          NeoSettingsGroup(
            palette: p,
            title: t.title,
            description: t.description,
            gap: c.error == null ? 28 : 8,
            trailing: c.canSignOutEverywhere && c.hasOthers
                ? OutlinedButton(
                    onPressed: c.busy == null ? _signOutEverywhere : null,
                    child: Text(t.signOutEverywhere),
                  )
                : null,
            children: rows,
          ),
          if (c.error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 28),
              child: Text(
                widget.describeError(c.error!),
                style: TextStyle(color: p.danger, fontSize: 13),
              ),
            ),
        ],
      );
    },
  );
}

/// Wording of [NeoAccountDataGroup] and its dialogs.
class NeoAccountDataTexts {
  const NeoAccountDataTexts({
    required this.title,
    this.description,
    required this.exportLabel,
    this.exportDescription,
    required this.exportButton,
    required this.exportTitle,
    required this.deleteLabel,
    this.deleteDescription,
    required this.deleteButton,
    required this.deleteTitle,
    this.deleteMessage,
    required this.passwordLabel,
    required this.codeLabel,
    required this.confirmLabel,
    required this.cancel,
  });

  final String title, exportLabel, exportButton, exportTitle;
  final String deleteLabel, deleteButton, deleteTitle;
  final String passwordLabel, codeLabel, cancel;
  final String? description, exportDescription, deleteDescription;
  final String? deleteMessage;

  /// The label of the typed confirmation, given the phrase to type.
  final String Function(String phrase) confirmLabel;
}

/// "Your data" on one settings card: download an export and delete the
/// account, each behind the identity dialog the server's rules need.
class NeoAccountDataGroup extends StatefulWidget {
  const NeoAccountDataGroup({
    super.key,
    required this.palette,
    required this.api,
    required this.texts,
    required this.username,
    required this.save,
    required this.onDeleted,
    required this.describeError,
    this.hasPassword = true,
    this.twoFactor = false,
    this.exportNeedsIdentity = true,
    this.deleteNeedsUsername = true,
    this.deleteBlocked,
    this.deleteDetails,
    this.onExported,
  });

  final NeoLabsPalette palette;
  final NeoAccountApi api;
  final NeoAccountDataTexts texts;

  /// The phrase typed to confirm deletion.
  final String username;

  /// Saves the export: a browser download or a save dialog.
  final Future<void> Function(NeoDownload file) save;

  /// Runs after the account is gone: clear local data and sign out.
  final Future<void> Function() onDeleted;
  final void Function(NeoDownload file)? onExported;
  final String Function(Object error) describeError;

  /// The account signs in with a password; asked for in the dialogs.
  final bool hasPassword;

  /// 2FA is on; its code is asked for in the dialogs.
  final bool twoFactor;
  final bool exportNeedsIdentity;
  final bool deleteNeedsUsername;

  /// Why the account cannot delete itself (the only admin, say); the delete
  /// button is disabled with this as its help.
  final String? deleteBlocked;

  /// What deletion erases and keeps, shown in its dialog.
  final Widget? deleteDetails;

  @override
  State<NeoAccountDataGroup> createState() => _NeoAccountDataGroupState();
}

class _NeoAccountDataGroupState extends State<NeoAccountDataGroup> {
  bool exporting = false;
  String? error;

  Future<String?> _attempt(Future<void> Function() work) async {
    try {
      await work();
      return null;
    } catch (e) {
      return widget.describeError(e);
    }
  }

  Future<void> _download(NeoIdentity identity) async {
    final file = await widget.api.exportData(identity);
    await widget.save(file);
    widget.onExported?.call(file);
  }

  Future<void> _export() async {
    final t = widget.texts;
    final needsDialog =
        widget.exportNeedsIdentity && (widget.hasPassword || widget.twoFactor);
    if (needsDialog) {
      await NeoConfirmIdentityDialog.show(
        context,
        NeoConfirmIdentityDialog(
          title: t.exportTitle,
          cancelLabel: t.cancel,
          submitLabel: t.exportButton,
          askPassword: widget.hasPassword,
          passwordLabel: t.passwordLabel,
          askCode: widget.twoFactor,
          codeLabel: t.codeLabel,
          onSubmit: (identity) => _attempt(() => _download(identity)),
        ),
      );
      return;
    }
    setState(() {
      exporting = true;
      error = null;
    });
    final refusal = await _attempt(() => _download(const NeoIdentity()));
    if (mounted) {
      setState(() {
        exporting = false;
        error = refusal;
      });
    }
  }

  Future<void> _delete() async {
    final t = widget.texts;
    final deleted = await NeoConfirmIdentityDialog.show(
      context,
      NeoConfirmIdentityDialog(
        title: t.deleteTitle,
        message: t.deleteMessage,
        details: widget.deleteDetails,
        cancelLabel: t.cancel,
        submitLabel: t.deleteButton,
        destructive: true,
        askPassword: widget.hasPassword,
        passwordLabel: t.passwordLabel,
        askCode: widget.twoFactor,
        codeLabel: t.codeLabel,
        confirmPhrase: widget.deleteNeedsUsername ? widget.username : null,
        confirmLabel: t.confirmLabel(widget.username),
        onSubmit: (identity) =>
            _attempt(() => widget.api.deleteAccount(identity)),
      ),
    );
    if (deleted) await widget.onDeleted();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.texts;
    final p = widget.palette;
    final blocked = widget.deleteBlocked;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        NeoSettingsGroup(
          palette: p,
          title: t.title,
          description: t.description,
          gap: error == null ? 28 : 8,
          children: <Widget>[
            NeoSettingsRow(
              palette: p,
              label: t.exportLabel,
              description: t.exportDescription,
              control: OutlinedButton(
                onPressed: exporting ? null : _export,
                child: exporting
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(t.exportButton),
              ),
            ),
            NeoSettingsRow(
              palette: p,
              label: t.deleteLabel,
              description: blocked ?? t.deleteDescription,
              control: OutlinedButton(
                style: OutlinedButton.styleFrom(foregroundColor: p.danger),
                onPressed: blocked == null ? _delete : null,
                child: Text(t.deleteButton),
              ),
            ),
          ],
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 28),
            child: Text(
              error!,
              style: TextStyle(color: p.danger, fontSize: 13),
            ),
          ),
      ],
    );
  }
}
