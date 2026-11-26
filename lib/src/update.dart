import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'palette.dart';
import 'settings_blocks.dart';

/// Updating a NeoLabs server from its admin pages: the banner that offers a new
/// version and follows the update while it runs, and the updates settings. The
/// server runs the same flow as the app's `update` command; this only shows it.

/// What the server knows about updates: the installed version, a newer one
/// waiting on the channel, and the update job when one ran.
class NeoUpdateStatus {
  factory NeoUpdateStatus(Map<String, dynamic> json) {
    final available = json['available'] is Map
        ? json['available'] as Map
        : null;
    final job = json['job'] is Map ? json['job'] as Map : const {};
    List<String> strings(Object? value) =>
        value is List ? [for (final item in value) '$item'] : const <String>[];
    DateTime? time(Object? value) =>
        DateTime.tryParse('${value ?? ''}')?.toLocal();
    final progress = job['progress'];
    return NeoUpdateStatus._(
      version: '${json['version'] ?? ''}',
      channel: '${json['channel'] ?? 'beta'}',
      selfUpdate: json['selfUpdate'] == true,
      blockedReason: json['blockedReason']?.toString(),
      checkedAt: time(json['checkedAt']),
      checkFailed: json['checkFailed'] == true,
      hasAvailable: available != null,
      availableVersion: available?['version']?.toString(),
      changes: strings(available?['changes']),
      state: '${job['state'] ?? 'idle'}',
      progress: progress is num ? progress.toInt().clamp(0, 100) : 0,
      message: '${job['message'] ?? ''}',
      versionAfter: job['versionAfter']?.toString(),
      logs: strings(job['logs']),
      completedAt: time(job['completedAt']),
    );
  }

  const NeoUpdateStatus._({
    required this.version,
    required this.channel,
    required this.selfUpdate,
    required this.blockedReason,
    required this.checkedAt,
    required this.checkFailed,
    required this.hasAvailable,
    required this.availableVersion,
    required this.changes,
    required this.state,
    required this.progress,
    required this.message,
    required this.versionAfter,
    required this.logs,
    required this.completedAt,
  });

  final String version;
  final String channel;
  final bool selfUpdate;
  final String? blockedReason;
  final DateTime? checkedAt;
  final bool checkFailed;
  final bool hasAvailable;
  final String? availableVersion;
  final List<String> changes;
  final String state;
  final int progress;
  final String message;
  final String? versionAfter;
  final List<String> logs;
  final DateTime? completedAt;

  bool get running => state == 'running';
  bool get canStart => hasAvailable && selfUpdate;
}

/// A refused or failed request. [status] is the HTTP status, or null when the
/// server was not reached.
typedef NeoUpdateFailure = ({int? status, String message});

/// The server calls, supplied by the application with its session handling.
class NeoUpdateApi {
  const NeoUpdateApi({
    required this.status,
    required this.check,
    required this.start,
    required this.setChannel,
    required this.failureOf,
  });

  final Future<Map<String, dynamic>> Function() status;
  final Future<Map<String, dynamic>> Function() check;
  final Future<Map<String, dynamic>> Function() start;
  final Future<Map<String, dynamic>> Function(String channel) setChannel;

  /// Reads the application's request error; null for anything else.
  final NeoUpdateFailure? Function(Object error) failureOf;
}

/// Loads the update status, starts updates and follows them to the end, also
/// across the server restart in the middle of one.
class NeoUpdateController extends ChangeNotifier {
  NeoUpdateController(this.api);

  final NeoUpdateApi api;
  NeoUpdateStatus? status;
  bool busy = false;
  bool reconnecting = false;
  String? error;
  DateTime? _dismissedAt;
  bool _followed = false;
  bool _disposed = false;
  Timer? _timer;

  /// A failed update is news for half an hour, or until it is dismissed. A
  /// finished one is only news on the page that watched it run: after the
  /// reload it has been delivered.
  bool get finishedRecently {
    final done = status?.completedAt;
    if (done == null || done == _dismissedAt) return false;
    if (status!.state == 'completed') return _followed;
    return status!.state == 'failed' &&
        DateTime.now().difference(done) < const Duration(minutes: 30);
  }

  bool get justUpdated => _followed && status?.state == 'completed';

  void dismiss() {
    _dismissedAt = status?.completedAt;
    notifyListeners();
  }

  Future<void> load() => _fetch(api.status);

  Future<void> check() => _guard(() => _fetch(api.check, rethrowErrors: true));

  Future<void> setChannel(String channel) =>
      _guard(() => _fetch(() => api.setChannel(channel), rethrowErrors: true));

  Future<void> start() => _guard(() {
    _followed = true;
    return _fetch(api.start, rethrowErrors: true);
  });

  Future<void> _guard(Future<void> Function() action) async {
    busy = true;
    error = null;
    _notify();
    try {
      await action();
    } catch (failure) {
      final known = api.failureOf(failure);
      if (known == null) rethrow;
      error = known.message;
    } finally {
      busy = false;
      _notify();
    }
  }

  Future<void> _fetch(
    Future<Map<String, dynamic>> Function() request, {
    bool rethrowErrors = false,
  }) async {
    try {
      status = NeoUpdateStatus(await request());
      reconnecting = false;
      if (status!.running) _followed = true;
    } catch (failure) {
      // The server going away mid-update is expected; anything else is shown.
      final code = api.failureOf(failure)?.status;
      if (_followed && (code == null || code == 0 || code >= 502)) {
        reconnecting = true;
      } else if (rethrowErrors) {
        rethrow;
      }
    }
    _schedule();
    _notify();
  }

  void _schedule() {
    _timer?.cancel();
    if (_disposed || !(status?.running == true || reconnecting)) return;
    _timer = Timer(const Duration(seconds: 2), load);
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    super.dispose();
  }
}

/// The wording of the update banner and settings, in the app's language.
class NeoUpdateStrings {
  const NeoUpdateStrings({
    required this.title,
    required this.description,
    required this.versionLabel,
    required this.channelLabel,
    required this.channelHint,
    required this.stable,
    required this.beta,
    required this.checkNow,
    required this.neverChecked,
    required this.checkedAt,
    required this.upToDate,
    required this.checkFailed,
    required this.details,
    required this.blocked,
    required this.readyTitle,
    required this.readySubtitle,
    required this.whatsNew,
    required this.updateNow,
    required this.confirmTitle,
    required this.confirmMessage,
    required this.cancel,
    required this.updatingTitle,
    required this.updatingToTitle,
    required this.reconnecting,
    required this.handsOff,
    required this.doneTitle,
    required this.doneReloading,
    required this.reload,
    required this.failedTitle,
    required this.close,
    required this.retry,
  });

  final String title;
  final String description;
  final String versionLabel;
  final String channelLabel;
  final String channelHint;
  final String stable;
  final String beta;
  final String checkNow;
  final String neverChecked;
  final String Function(DateTime checkedAt) checkedAt;
  final String upToDate;
  final String checkFailed;
  final String details;

  /// Why this install cannot update itself, from the server's reason such as
  /// `container`.
  final ({String title, String hint}) Function(String? reason) blocked;
  final String Function(String version) readyTitle;
  final String Function(String installed, String channel) readySubtitle;
  final String whatsNew;
  final String updateNow;
  final String Function(String version) confirmTitle;
  final String confirmMessage;
  final String cancel;
  final String updatingTitle;
  final String Function(String version) updatingToTitle;
  final String reconnecting;
  final String handsOff;
  final String Function(String version) doneTitle;
  final String doneReloading;
  final String reload;
  final String failedTitle;
  final String close;
  final String retry;

  String channel(String value) => value == 'stable' ? stable : beta;
}

/// The banner above every admin area. It offers the update, then shows its
/// progress, then the result; with nothing to say it takes no space.
class NeoUpdateBanner extends StatefulWidget {
  const NeoUpdateBanner({
    super.key,
    required this.palette,
    required this.controller,
    required this.strings,
    this.onReload,
  });

  final NeoLabsPalette palette;
  final NeoUpdateController controller;
  final NeoUpdateStrings strings;

  /// Loads the client again after an update replaced it. Null where there is
  /// no page to reload.
  final VoidCallback? onReload;

  @override
  State<NeoUpdateBanner> createState() => _NeoUpdateBannerState();
}

class _NeoUpdateBannerState extends State<NeoUpdateBanner> {
  bool _showChanges = false;
  Timer? _reload;

  NeoUpdateController get controller => widget.controller;
  NeoUpdateStrings get strings => widget.strings;
  NeoLabsPalette get palette => widget.palette;

  @override
  void dispose() {
    _reload?.cancel();
    super.dispose();
  }

  Future<void> _confirmAndStart(NeoUpdateStatus status) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(strings.confirmTitle(status.availableVersion ?? '')),
        content: SizedBox(width: 400, child: Text(strings.confirmMessage)),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(strings.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(strings.updateNow),
          ),
        ],
      ),
    );
    if (confirmed == true) await controller.start();
  }

  void _reloadSoon() {
    final reload = widget.onReload;
    if (_reload != null || reload == null) return;
    _reload = Timer(const Duration(seconds: 3), reload);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final status = controller.status;
      if (status == null) return const SizedBox.shrink();
      if (status.running || controller.reconnecting) {
        return _frame(palette.accent, _running(status));
      }
      if (controller.finishedRecently) {
        if (status.state == 'completed') {
          if (controller.justUpdated) _reloadSoon();
          return _frame(palette.success, _completed(status));
        }
        return _frame(palette.danger, _failed(status));
      }
      if (status.canStart) return _frame(palette.accent, _available(status));
      return const SizedBox.shrink();
    },
  );

  Widget _frame(Color tone, Widget child) => Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tone.withValues(alpha: 0.4)),
      ),
      child: child,
    ),
  );

  Widget _heading(
    IconData icon,
    Color tone,
    String title,
    String? subtitle, {
    List<Widget> actions = const <Widget>[],
  }) {
    final text = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(icon, size: 20, color: tone),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title,
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                  color: palette.textPrimary,
                ),
              ),
              if (subtitle != null && subtitle.isNotEmpty) ...<Widget>[
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 13,
                    color: palette.textSecondary,
                    height: 1.45,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
    if (actions.isEmpty) return text;
    final buttons = Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: actions,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        // Beside the text, buttons would leave it a few letters wide on a phone.
        if (constraints.maxWidth < 520) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              text,
              Padding(
                padding: const EdgeInsets.only(left: 32, top: 10),
                child: buttons,
              ),
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(child: text),
            const SizedBox(width: 12),
            buttons,
          ],
        );
      },
    );
  }

  Widget _available(NeoUpdateStatus status) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      _heading(
        Icons.system_update_alt,
        palette.accent,
        strings.readyTitle(status.availableVersion ?? ''),
        strings.readySubtitle(status.version, strings.channel(status.channel)),
        actions: <Widget>[
          if (status.changes.isNotEmpty)
            TextButton(
              onPressed: () => setState(() => _showChanges = !_showChanges),
              child: Text(strings.whatsNew),
            ),
          FilledButton(
            onPressed: controller.busy ? null : () => _confirmAndStart(status),
            child: Text(strings.updateNow),
          ),
        ],
      ),
      if (_showChanges)
        Padding(
          padding: const EdgeInsets.only(left: 32, top: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              for (final change in status.changes)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    '•  $change',
                    style: TextStyle(
                      fontSize: 13,
                      color: palette.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ),
            ],
          ),
        ),
      if (controller.error != null)
        Padding(
          padding: const EdgeInsets.only(left: 32, top: 10),
          child: Text(
            controller.error!,
            style: TextStyle(fontSize: 13, color: palette.danger),
          ),
        ),
    ],
  );

  Widget _running(NeoUpdateStatus status) {
    final target = status.versionAfter;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _heading(
          Icons.sync,
          palette.accent,
          target == null || target.isEmpty
              ? strings.updatingTitle
              : strings.updatingToTitle(target),
          controller.reconnecting ? strings.reconnecting : status.message,
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: controller.reconnecting ? null : status.progress / 100,
            minHeight: 5,
            backgroundColor: palette.border,
            valueColor: AlwaysStoppedAnimation<Color>(palette.accent),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          strings.handsOff,
          style: TextStyle(fontSize: 12.5, color: palette.textMuted),
        ),
      ],
    );
  }

  Widget _completed(NeoUpdateStatus status) => _heading(
    Icons.check_circle_outline,
    palette.success,
    strings.doneTitle(status.versionAfter ?? status.version),
    widget.onReload == null ? null : strings.doneReloading,
    actions: <Widget>[
      TextButton(onPressed: controller.dismiss, child: Text(strings.close)),
      if (widget.onReload != null)
        FilledButton(onPressed: widget.onReload, child: Text(strings.reload)),
    ],
  );

  Widget _failed(NeoUpdateStatus status) => _heading(
    Icons.error_outline,
    palette.danger,
    strings.failedTitle,
    status.message,
    actions: <Widget>[
      TextButton(onPressed: controller.dismiss, child: Text(strings.close)),
      if (status.canStart)
        FilledButton(
          onPressed: controller.busy ? null : () => _confirmAndStart(status),
          child: Text(strings.retry),
        ),
    ],
  );
}

/// The updates settings: version, check now, channel, why an install cannot
/// update itself, and the log of the last run.
class NeoUpdateSettings extends StatelessWidget {
  const NeoUpdateSettings({
    super.key,
    required this.palette,
    required this.controller,
    required this.strings,
  });

  final NeoLabsPalette palette;
  final NeoUpdateController controller;
  final NeoUpdateStrings strings;

  TextStyle _mono(double size) => GoogleFonts.geistMono(
    fontSize: size,
    color: palette.textSecondary,
    height: 1.5,
  );

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final status = controller.status;
      if (status == null) return const SizedBox.shrink();
      final locked = status.running || controller.busy || !status.selfUpdate;
      final checked = status.checkedAt == null
          ? strings.neverChecked
          : strings.checkedAt(status.checkedAt!);
      final summary = status.hasAvailable
          ? strings.readyTitle(status.availableVersion ?? '')
          : status.checkFailed
          ? strings.checkFailed
          : status.checkedAt == null
          ? checked
          : '${strings.upToDate} · $checked';
      final blocked = status.selfUpdate
          ? null
          : strings.blocked(status.blockedReason);
      return NeoSettingsGroup(
        palette: palette,
        title: strings.title,
        description: strings.description,
        trailing: OutlinedButton.icon(
          onPressed: locked ? null : controller.check,
          icon: controller.busy
              ? const SizedBox.square(
                  dimension: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.refresh, size: 18),
          label: Text(strings.checkNow),
        ),
        children: <Widget>[
          NeoSettingsRow(
            palette: palette,
            label: strings.versionLabel,
            description: summary,
            control: SelectableText(status.version, style: _mono(13)),
          ),
          NeoSettingsRow(
            palette: palette,
            label: strings.channelLabel,
            description: strings.channelHint,
            control: SegmentedButton<String>(
              showSelectedIcon: false,
              segments: <ButtonSegment<String>>[
                ButtonSegment<String>(
                  value: 'stable',
                  label: Text(strings.stable),
                ),
                ButtonSegment<String>(value: 'beta', label: Text(strings.beta)),
              ],
              selected: <String>{status.channel},
              onSelectionChanged: locked
                  ? null
                  : (selection) => controller.setChannel(selection.first),
            ),
          ),
          if (blocked != null)
            NeoSettingsRow(
              palette: palette,
              label: blocked.title,
              description: blocked.hint,
              control: status.blockedReason == 'container'
                  ? SelectableText(
                      'docker compose pull\ndocker compose up -d',
                      style: _mono(13),
                    )
                  : null,
            ),
          if (status.logs.isNotEmpty)
            ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(horizontal: 20),
              shape: const Border(),
              collapsedShape: const Border(),
              title: Text(
                strings.details,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: palette.textPrimary,
                ),
              ),
              children: <Widget>[
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 240),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: SelectableText(
                        status.logs.join('\n'),
                        style: _mono(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          if (controller.error != null)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                controller.error!,
                style: TextStyle(fontSize: 13, color: palette.danger),
              ),
            ),
        ],
      );
    },
  );
}
