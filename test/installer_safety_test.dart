import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:neolabs_flutter/installer.dart';

NeoRuntimeApp _app({String publicKey = ''}) => NeoRuntimeApp(
  name: 'Demo',
  command: 'demo',
  repository: 'owner/demo',
  publicKey: publicKey,
  targets: const <String, List<String>>{
    'macos': <String>['arm64'],
    'windows': <String>['x64'],
  },
  webIndex: const <String>['public', 'index.html'],
  strings: (text) => text.name,
);

Matcher _failsWith(String code) =>
    throwsA(isA<NeoInstallerException>().having((e) => e.code, 'code', code));

List<int> _manifest({
  String version = '3.4.0',
  String assetName = 'demo-runtime.zip',
}) => utf8.encode(
  jsonEncode(<String, Object>{
    'schemaVersion': 1,
    'version': version,
    'artifacts': <Object>[
      <String, Object>{
        'platform': 'macos',
        'architecture': 'arm64',
        'assetName': assetName,
        'sha256': 'a' * 64,
        'sizeBytes': 1024,
      },
    ],
  }),
);

/// Zips a staged tree, keeping links.
Future<File> _zip(Directory root, Directory stage) async {
  final zip = File('${root.path}/runtime.zip');
  final result = Process.runSync('zip', <String>[
    '-qry',
    zip.path,
    '.',
  ], workingDirectory: stage.path);
  expect(result.exitCode, 0, reason: '${result.stderr}');
  return zip;
}

void main() {
  late Directory root;
  setUp(() => root = Directory.systemTemp.createTempSync('neo-safety-'));
  tearDown(() => root.deleteSync(recursive: true));

  test('the manifest picks exactly this platform and architecture', () {
    ({String version, NeoRuntimeArtifact artifact}) pick(String platform) =>
        selectRuntimeArtifact(
          _app(),
          _manifest(),
          platform: platform,
          architecture: platform == 'macos' ? 'arm64' : 'x64',
        );
    expect(pick('macos').artifact.assetName, 'demo-runtime.zip');
    expect(() => pick('windows'), _failsWith('SETUP_PLATFORM_UNSUPPORTED'));
  });

  test('a manifest cannot name paths', () {
    for (final bytes in <List<int>>[
      _manifest(version: '../../outside'),
      _manifest(assetName: '../../outside.zip'),
    ]) {
      expect(
        () => selectRuntimeArtifact(
          _app(),
          bytes,
          platform: 'macos',
          architecture: 'arm64',
        ),
        _failsWith('SETUP_MANIFEST_INVALID'),
      );
    }
  });

  test('signatures accept only the matching key, raw or SPKI', () async {
    final keys = await Ed25519().newKeyPair();
    final key = (await keys.extractPublicKey()).bytes;
    final bytes = utf8.encode('{"schemaVersion":1}');
    final signature = base64Encode(
      (await Ed25519().sign(bytes, keyPair: keys)).bytes,
    );
    const spki = <int>[48, 42, 48, 5, 6, 3, 43, 101, 112, 3, 33, 0];
    for (final encoded in <List<int>>[
      key,
      <int>[...spki, ...key],
    ]) {
      final app = _app(publicKey: base64Encode(encoded));
      await verifyRuntimeManifestSignature(
        app: app,
        manifestBytes: bytes,
        signatureBase64: signature,
      );
      await expectLater(
        verifyRuntimeManifestSignature(
          app: app,
          manifestBytes: utf8.encode('{"schemaVersion":2}'),
          signatureBase64: signature,
        ),
        _failsWith('SETUP_MANIFEST_SIGNATURE_INVALID'),
      );
    }
  });

  test('downloads require HTTPS', () async {
    final service = NeoRuntimeReleaseService(
      app: _app(),
      releases: Uri.parse('https://example.test/releases'),
      checkCancelled: () {},
      onDownloadProgress: (_) {},
      client: MockClient(
        (_) async => http.Response(
          jsonEncode(<Object>[
            <String, Object>{
              'assets': <Object>[
                for (final name in <String>[
                  'demo-runtime-manifest-1.json',
                  'demo-runtime-manifest-1.json.sig',
                ])
                  <String, String>{
                    'name': name,
                    'browser_download_url': 'http://example.test/$name',
                  },
              ],
            },
          ]),
          200,
        ),
      ),
    );
    await expectLater(
      service.prepare(
        platform: 'macos',
        architecture: 'arm64',
        channel: 'stable',
      ),
      _failsWith('SETUP_DOWNLOAD_URL_INVALID'),
    );
  });

  test('archive paths and links cannot escape', () {
    expect(isSafeRuntimeArchivePath('app/bin/demo'), isTrue);
    expect(isSafeRuntimeArchivePath('../outside'), isFalse);
    expect(isSafeRuntimeArchivePath(r'C:\outside'), isFalse);
    expect(
      isSafeRuntimeArchivePath('../../outside', basePath: 'app/bin'),
      isTrue,
    );
    expect(
      isSafeRuntimeArchivePath('../../../outside', basePath: 'app/bin'),
      isFalse,
    );
    expect(
      rewriteRuntimeSymlinkTarget(
        'app/node_modules/.bin/bw',
        '/Users/runner/work/x/node_modules/@bitwarden/cli/build/bw.js',
      ),
      '../@bitwarden/cli/build/bw.js',
    );
    expect(rewriteRuntimeSymlinkTarget('app/bin/tool', '/etc/passwd'), isNull);
    expect(
      rewriteRuntimeSymlinkTarget('app/bin/tool', '../../../../etc/passwd'),
      isNull,
    );
  });

  test(
    'an extracted binary runs and absolute module links are remapped',
    () async {
      final stage = Directory('${root.path}/stage');
      for (final path in <String>[
        'app/bin',
        'app/public',
        'app/node_modules/.bin',
        'app/node_modules/demo-cli',
      ]) {
        Directory('${stage.path}/$path').createSync(recursive: true);
      }
      final binary = File('${stage.path}/app/bin/demo')
        ..writeAsStringSync('#!/bin/sh\necho ok\n');
      File('${stage.path}/app/public/index.html').writeAsStringSync('<html>');
      final cli = File('${stage.path}/app/node_modules/demo-cli/cli.js')
        ..writeAsStringSync('ok\n');
      Link('${stage.path}/app/node_modules/.bin/demo').createSync(cli.path);
      Process.runSync('chmod', <String>['755', binary.path]);
      final zip = await _zip(root, stage);

      final extracted = Directory('${root.path}/extracted')..createSync();
      await extractVerifiedRuntimeArchive(_app(), zip.path, extracted.path);

      final activation = NeoRuntimeActivation(_app());
      expect(activation.isComplete(extracted), isTrue);
      final run = Process.runSync(
        activation.executable(extracted).path,
        const <String>[],
      );
      expect('${run.stdout}', contains('ok'));
      final link = Link('${extracted.path}/app/node_modules/.bin/demo');
      expect(link.targetSync(), '../demo-cli/cli.js');
    },
    skip: Platform.isWindows,
  );

  test('zip-slip entry names are refused', () async {
    final zip = File('${root.path}/runtime.zip');
    final created = Process.runSync('python3', <String>[
      '-c',
      'import zipfile, sys\n'
          'a = zipfile.ZipFile(sys.argv[1], "w")\n'
          'a.writestr("app/ok.txt", "ok")\n'
          'a.writestr("../outside.txt", "no")\n'
          'a.close()',
      zip.path,
    ]);
    expect(created.exitCode, 0, reason: '${created.stderr}');
    await expectLater(
      extractVerifiedRuntimeArchive(_app(), zip.path, '${root.path}/extracted'),
      _failsWith('SETUP_RUNTIME_ARCHIVE_INVALID'),
    );
    expect(File('${root.path}/outside.txt').existsSync(), isFalse);
  }, skip: Platform.isWindows);

  test('activation returns the previous version and can restore it', () async {
    final activation = NeoRuntimeActivation(_app());
    expect(await activation.activate(root, '3.3.0'), isNull);
    expect(await activation.activate(root, '3.4.0'), '3.3.0');
    expect(activation.currentVersion(root), '3.4.0');
    await activation.restore(root, '3.3.0');
    expect(activation.currentVersion(root), '3.3.0');
    await activation.restore(root, null);
    expect(activation.currentVersion(root), isNull);
  });
}
