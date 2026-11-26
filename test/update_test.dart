import 'package:fake_async/fake_async.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neolabs_flutter/neolabs_flutter.dart';

class _Refused implements Exception {
  _Refused(this.status);
  final int? status;
}

NeoUpdateApi _api(Future<Map<String, dynamic>> Function() answer) =>
    NeoUpdateApi(
      status: answer,
      check: answer,
      start: answer,
      setChannel: (_) => answer(),
      failureOf: (error) => error is _Refused
          ? (status: error.status, message: 'refused ${error.status}')
          : null,
    );

Map<String, dynamic> _status({
  String state = 'idle',
  Map<String, dynamic>? available,
  bool selfUpdate = true,
  String? completedAt,
}) => {
  'version': '1.0.0',
  'channel': 'beta',
  'selfUpdate': selfUpdate,
  if (!selfUpdate) 'blockedReason': 'container',
  'available': available,
  'job': {'state': state, 'progress': 40, 'completedAt': completedAt},
};

final _strings = NeoUpdateStrings(
  title: 'Updates',
  description: 'Keep the server current',
  versionLabel: 'Version',
  channelLabel: 'Channel',
  channelHint: 'Which releases',
  stable: 'Stable',
  beta: 'Beta',
  checkNow: 'Check now',
  neverChecked: 'Never checked',
  checkedAt: (_) => 'Checked',
  upToDate: 'Up to date',
  checkFailed: 'Check failed',
  details: 'Details',
  blocked: (reason) => (title: 'Blocked: $reason', hint: 'Pull the image'),
  readyTitle: (version) => '$version is ready',
  readySubtitle: (installed, channel) => 'You run $installed on $channel',
  whatsNew: "What's new",
  updateNow: 'Update now',
  confirmTitle: (version) => 'Install $version?',
  confirmMessage: 'The server restarts',
  cancel: 'Cancel',
  updatingTitle: 'Updating',
  updatingToTitle: (version) => 'Updating to $version',
  reconnecting: 'Reconnecting',
  handsOff: 'Leave this open',
  doneTitle: (version) => 'Updated to $version',
  doneReloading: 'Reloading',
  reload: 'Reload',
  failedTitle: 'Update failed',
  close: 'Close',
  retry: 'Retry',
);

void main() {
  test('follows a started update across the server restart', () {
    fakeAsync((async) {
      final answers = <Object>[
        _status(state: 'running'),
        _Refused(null),
        _Refused(503),
        _status(
          state: 'completed',
          completedAt: DateTime.now().toIso8601String(),
        ),
      ];
      final controller = NeoUpdateController(
        _api(() async {
          final next = answers.removeAt(0);
          if (next is Exception) throw next;
          return next as Map<String, dynamic>;
        }),
      );
      controller.start();
      async.flushMicrotasks();
      expect(controller.status!.running, isTrue);
      async.elapse(const Duration(seconds: 2));
      expect(controller.reconnecting, isTrue);
      async.elapse(const Duration(seconds: 2));
      expect(controller.reconnecting, isTrue);
      async.elapse(const Duration(seconds: 2));
      expect(controller.reconnecting, isFalse);
      expect(controller.justUpdated, isTrue);
      expect(controller.finishedRecently, isTrue);
      async.elapse(const Duration(seconds: 10));
      expect(answers, isEmpty);
      controller.dispose();
    });
  });

  test('shows why a request was refused', () async {
    final controller = NeoUpdateController(
      _api(() async => throw _Refused(403)),
    );
    await controller.check();
    expect(controller.error, 'refused 403');
    expect(controller.busy, isFalse);
    controller.dispose();
  });

  testWidgets('offers an update and asks before starting it', (tester) async {
    var starts = 0;
    final offered = _status(available: {'version': '1.1.0', 'changes': []});
    final controller = NeoUpdateController(
      NeoUpdateApi(
        status: () async => offered,
        check: () async => offered,
        start: () async {
          starts++;
          return offered;
        },
        setChannel: (_) async => offered,
        failureOf: (_) => null,
      ),
    );
    addTearDown(controller.dispose);
    await controller.load();
    for (final width in <double>[360, 900]) {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView(
              children: [
                NeoUpdateBanner(
                  palette: darkPalette,
                  controller: controller,
                  strings: _strings,
                ),
                NeoUpdateSettings(
                  palette: darkPalette,
                  controller: controller,
                  strings: _strings,
                ),
              ],
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('1.1.0 is ready'), findsNWidgets(2));
    }
    await tester.tap(find.widgetWithText(FilledButton, 'Update now'));
    await tester.pumpAndSettle();
    expect(starts, 0);
    await tester.tap(find.widgetWithText(FilledButton, 'Update now').last);
    await tester.pumpAndSettle();
    expect(starts, 1);
  });

  testWidgets('says why a container cannot update itself', (tester) async {
    final controller = NeoUpdateController(
      _api(() async => _status(selfUpdate: false)),
    );
    addTearDown(controller.dispose);
    await controller.load();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NeoUpdateSettings(
            palette: lightPalette,
            controller: controller,
            strings: _strings,
          ),
        ),
      ),
    );
    expect(find.text('Blocked: container'), findsOneWidget);
    expect(find.textContaining('docker compose pull'), findsOneWidget);
    // `OutlinedButton.icon` builds a subclass, which `byType` does not match.
    final check = tester.widget<OutlinedButton>(
      find.byWidgetPredicate((widget) => widget is OutlinedButton),
    );
    expect(check.onPressed, isNull);
  });
}
