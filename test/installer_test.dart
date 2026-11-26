import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart' as digests;
import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:neolabs_flutter/installer.dart';

/// A signed release served from memory, for the running platform.
Future<({NeoRuntimeApp app, http.Client client})> _release({
  bool tamper = false,
}) async {
  final zip = Archive()
    ..addFile(ArchiveFile.string('app/bin/demo', '#!/bin/sh\nexit 0\n'))
    ..addFile(ArchiveFile.string('app/public/index.html', '<html></html>'));
  final bytes = ZipEncoder().encode(zip);
  final platform = Platform.isMacOS ? 'macos' : 'linux';
  final manifest = utf8.encode(
    jsonEncode(<String, Object>{
      'schemaVersion': 1,
      'version': '2.0.0',
      'artifacts': <Object>[
        for (final arch in <String>['x64', 'arm64'])
          <String, Object>{
            'platform': platform,
            'architecture': arch,
            'assetName': 'demo.zip',
            'sha256': '${digests.sha256.convert(bytes)}',
            'sizeBytes': bytes.length,
          },
      ],
    }),
  );
  final keys = await Ed25519().newKeyPair();
  final signature = await Ed25519().sign(manifest, keyPair: keys);
  final app = NeoRuntimeApp(
    name: 'Demo',
    command: 'demo',
    repository: 'owner/demo',
    publicKey: base64Encode((await keys.extractPublicKey()).bytes),
    targets: const <String, List<String>>{
      'macos': <String>['x64', 'arm64'],
      'linux': <String>['x64', 'arm64'],
    },
    webIndex: const <String>['public', 'index.html'],
    strings: (text) => text.name,
  );
  const base = 'https://example.test/';
  final files = <String, List<int>>{
    'demo-runtime-manifest-2.0.0.json': tamper
        ? <int>[...manifest, 32]
        : manifest,
    'demo-runtime-manifest-2.0.0.json.sig': utf8.encode(
      base64Encode(signature.bytes),
    ),
    'demo.zip': bytes,
  };
  final client = MockClient((request) async {
    if (request.url.path == '/releases') {
      return http.Response(
        jsonEncode(<Object>[
          <String, Object>{
            'prerelease': false,
            'draft': false,
            'assets': <Object>[
              for (final name in files.keys)
                <String, String>{
                  'name': name,
                  'browser_download_url': '$base$name',
                },
            ],
          },
        ]),
        200,
      );
    }
    return http.Response.bytes(files[request.url.pathSegments.last]!, 200);
  });
  return (app: app, client: client);
}

void main() {
  late Directory home;
  setUp(() => home = Directory.systemTemp.createTempSync('neo-install-'));
  tearDown(() => home.deleteSync(recursive: true));

  Future<String> install(
    ({NeoRuntimeApp app, http.Client client}) release, {
    bool failConfigure = false,
  }) {
    final installer = NeoRuntimeInstaller(
      app: release.app,
      client: release.client,
      releases: Uri.parse('https://example.test/releases'),
      onEvent: (_) {},
    );
    addTearDown(installer.dispose);
    return installer.install<String>(
      channel: 'stable',
      runtimeHome: home,
      rollbackArguments: (_) => const <String>['stop'],
      configure: (version, executable) async {
        if (failConfigure) throw StateError('setup failed');
        return executable.path;
      },
    );
  }

  test('installs and activates a signed runtime', () async {
    final release = await _release();
    final executable = await install(release);
    expect(File(executable).existsSync(), isTrue);
    expect(NeoRuntimeActivation(release.app).currentVersion(home), '2.0.0');
  }, skip: Platform.isWindows);

  test('a failed setup leaves no active runtime', () async {
    final release = await _release();
    await expectLater(
      install(release, failConfigure: true),
      throwsA(isA<NeoInstallerException>()),
    );
    expect(NeoRuntimeActivation(release.app).currentVersion(home), isNull);
  }, skip: Platform.isWindows);

  test(
    'a manifest that does not match its signature is refused',
    () async {
      await expectLater(
        install(await _release(tamper: true)),
        throwsA(
          isA<NeoInstallerException>().having(
            (e) => e.code,
            'code',
            'SETUP_MANIFEST_SIGNATURE_INVALID',
          ),
        ),
      );
      expect(Directory('${home.path}/app/versions').existsSync(), isFalse);
    },
    skip: Platform.isWindows,
  );

  test('archive paths cannot leave the runtime', () {
    expect(isSafeRuntimeArchivePath('app/bin/demo'), isTrue);
    for (final path in <String>['../x', '/etc/passwd', r'C:\x', 'a/../..']) {
      expect(isSafeRuntimeArchivePath(path), isFalse, reason: path);
    }
  });
}
