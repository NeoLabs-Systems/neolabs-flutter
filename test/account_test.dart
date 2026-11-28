import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neolabs_flutter/neolabs_flutter.dart';

class _Call {
  _Call(this.method, this.path, this.body);
  final String method, path;
  final Map<String, dynamic>? body;
}

class _FakeTransport implements NeoAccountTransport {
  final calls = <_Call>[];
  Map<String, dynamic> Function(_Call call) answer = (_) => <String, dynamic>{};
  Object? failWith;

  @override
  Future<Map<String, dynamic>> json(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final call = _Call(method, path, body);
    calls.add(call);
    if (failWith != null) throw failWith!;
    return answer(call);
  }

  @override
  Future<NeoDownload> download(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    calls.add(_Call(method, path, body));
    if (failWith != null) throw failWith!;
    return NeoDownload(
      bytes: Uint8List.fromList(utf8.encode('{}')),
      filename: 'export.json',
      mimeType: 'application/json',
    );
  }
}

const _palette = NeoLabsPalette(
  bgPrimary: Colors.white,
  bgSecondary: Colors.white,
  bgTertiary: Colors.white,
  bgCard: Colors.white,
  textPrimary: Colors.black,
  textSecondary: Colors.black54,
  textMuted: Colors.black38,
  accent: Colors.teal,
  accentHover: Colors.teal,
  accentAlt: Colors.teal,
  accentMuted: Colors.teal,
  border: Colors.black12,
  borderLight: Colors.black12,
  success: Colors.green,
  warning: Colors.orange,
  danger: Colors.red,
  info: Colors.blue,
);

Map<String, dynamic> _sessionsBody() => <String, dynamic>{
  'sessions': <dynamic>[
    <String, dynamic>{
      'id': 7,
      'current': true,
      'userAgent': 'Firefox',
      'ipAddress': null,
      'createdAt': '2026-11-01T10:00:00Z',
      'location': 'Berlin',
    },
    <String, dynamic>{
      'id': 'abc',
      'current': false,
      'userAgent': 'Phone',
      'lastSeenAt': '2026-11-02 08:30:00',
    },
  ],
};

void main() {
  test('the API uses the app routes and field names', () async {
    final t = _FakeTransport()..answer = (_) => _sessionsBody();
    final api = NeoAccountApi(
      t,
      routes: const NeoAccountRoutes(
        export: NeoAccountRoute('GET', '/api/v1/auth/account/export'),
        delete: NeoAccountRoute('DELETE', '/api/v1/auth/account'),
        revokeSession: NeoAccountRoute('DELETE', '/api/v1/sessions/{id}'),
      ),
      fields: const NeoAccountFields(
        password: 'password',
        code: 'twoFactorCode',
      ),
    );
    await api.exportData(const NeoIdentity(password: 'pw'));
    expect(t.calls.last.method, 'GET');
    expect(t.calls.last.body, isNull);
    await api.deleteAccount(
      const NeoIdentity(password: 'pw', code: ' 123456 ', confirmation: 'neo'),
    );
    expect(t.calls.last.path, '/api/v1/auth/account');
    expect(t.calls.last.body, <String, dynamic>{
      'password': 'pw',
      'twoFactorCode': '123456',
      'confirmUsername': 'neo',
    });
    final sessions = await api.sessions();
    expect(sessions.first.id, '7');
    expect(sessions.first.current, isTrue);
    expect(sessions.first.ipAddress, isNull);
    expect(sessions.first.createdAt, DateTime.utc(2026, 11, 1, 10));
    expect(sessions.first.extra, <String, dynamic>{'location': 'Berlin'});
    expect(sessions.last.lastSeenAt, DateTime.utc(2026, 11, 2, 8, 30));
    final left = await api.revokeSession('a/b');
    expect(t.calls.last.path, '/api/v1/sessions/a%2Fb');
    expect(left, hasLength(2));
    t.answer = (_) => <String, dynamic>{};
    expect(await api.signOutEverywhere(), isNull);
    expect(t.calls.last.path, '/api/account/sessions/revoke-all');
  });

  test('download names come only from the header file name', () {
    expect(
      NeoDownload.filenameFrom(
        'attachment; filename="neo-2026.json"',
        'x.json',
      ),
      'neo-2026.json',
    );
    expect(
      NeoDownload.filenameFrom('attachment; filename="../../etc/x"', 'f'),
      'x',
    );
    expect(NeoDownload.filenameFrom(null, 'fallback.zip'), 'fallback.zip');
  });

  testWidgets('the identity dialog waits for every answer it asks for', (
    tester,
  ) async {
    NeoIdentity? sent;
    var refusals = <String?>['Wrong password', null];
    bool? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await NeoConfirmIdentityDialog.show(
                context,
                NeoConfirmIdentityDialog(
                  title: 'Delete account',
                  cancelLabel: 'Cancel',
                  submitLabel: 'Delete',
                  passwordLabel: 'Password',
                  askCode: true,
                  codeLabel: 'Code',
                  confirmPhrase: 'Neo',
                  confirmLabel: 'Type Neo',
                  destructive: true,
                  onSubmit: (identity) async {
                    sent = identity;
                    final r = refusals.first;
                    refusals = refusals.sublist(1);
                    return r;
                  },
                ),
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    FilledButton submit() => tester.widget(find.byType(FilledButton));
    expect(submit().onPressed, isNull);
    await tester.enterText(find.widgetWithText(TextField, 'Password'), 'pw');
    await tester.enterText(find.widgetWithText(TextField, 'Code'), '12345');
    await tester.enterText(find.widgetWithText(TextField, 'Type Neo'), ' neo ');
    await tester.pump();
    expect(submit().onPressed, isNull, reason: 'codes have 6+ characters');
    await tester.enterText(find.widgetWithText(TextField, 'Code'), '123456');
    await tester.pump();
    expect(submit().onPressed, isNotNull);
    await tester.tap(find.text('Delete').last);
    await tester.pumpAndSettle();
    expect(find.text('Wrong password'), findsOneWidget);
    expect(sent?.password, 'pw');
    expect(sent?.code, '123456');
    expect(sent?.confirmation, 'neo');
    await tester.tap(find.text('Delete').last);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(result, isTrue);
  });

  testWidgets('sessions list ends one session and all others', (tester) async {
    final t = _FakeTransport();
    t.answer = (call) {
      if (call.method == 'DELETE') {
        return <String, dynamic>{
          'success': true,
          'sessions': <dynamic>[(_sessionsBody()['sessions'] as List).first],
        };
      }
      return _sessionsBody();
    };
    final controller = NeoSessionsController.api(NeoAccountApi(t));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: NeoSessionsGroup(
              palette: _palette,
              controller: controller,
              texts: const NeoSessionsTexts(
                title: 'Sessions',
                currentTag: 'This device',
                revoke: 'Sign out',
                signOutEverywhere: 'Sign out everywhere',
                empty: 'No sessions',
              ),
              label: (s) => s.userAgent ?? 'Unknown',
              describeError: (e) => 'Failed: $e',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Firefox'), findsOneWidget);
    expect(find.text('Phone'), findsOneWidget);
    expect(find.text('Sign out'), findsOneWidget, reason: 'not for this one');
    expect(find.text('Sign out everywhere'), findsOneWidget);
    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();
    expect(t.calls.last.path, '/api/account/sessions/abc');
    expect(find.text('Phone'), findsNothing);
    expect(find.text('Sign out everywhere'), findsNothing);

    t.failWith = 'offline';
    await controller.load();
    await tester.pumpAndSettle();
    expect(find.text('Failed: offline'), findsOneWidget);
  });

  testWidgets('account data exports, refuses while blocked and deletes', (
    tester,
  ) async {
    final t = _FakeTransport();
    final saved = <NeoDownload>[];
    var deleted = false;
    Widget group({String? blocked}) => MaterialApp(
      home: Scaffold(
        body: NeoAccountDataGroup(
          palette: _palette,
          api: NeoAccountApi(t),
          texts: NeoAccountDataTexts(
            title: 'Your data',
            exportLabel: 'Export',
            exportButton: 'Download',
            exportTitle: 'Confirm export',
            deleteLabel: 'Delete account',
            deleteButton: 'Delete',
            deleteTitle: 'Delete your account?',
            passwordLabel: 'Password',
            codeLabel: 'Code',
            confirmLabel: (phrase) => 'Type $phrase',
            cancel: 'Cancel',
          ),
          username: 'neo',
          exportNeedsIdentity: false,
          deleteBlocked: blocked,
          save: (file) async => saved.add(file),
          onDeleted: () async => deleted = true,
          describeError: (e) => '$e',
        ),
      ),
    );
    await tester.pumpWidget(group(blocked: 'Make someone else an admin.'));
    await tester.tap(find.text('Download'));
    await tester.pumpAndSettle();
    expect(saved, hasLength(1));
    expect(t.calls.single.path, '/api/account/export');
    expect(find.text('Make someone else an admin.'), findsOneWidget);
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);

    await tester.pumpWidget(group());
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Password'), 'pw');
    await tester.enterText(find.widgetWithText(TextField, 'Type neo'), 'NEO');
    await tester.pump();
    await tester.tap(find.text('Delete').last);
    await tester.pumpAndSettle();
    expect(t.calls.last.path, '/api/account/delete');
    expect(t.calls.last.body, <String, dynamic>{
      'currentPassword': 'pw',
      'confirmUsername': 'NEO',
    });
    expect(deleted, isTrue);
  });
}
