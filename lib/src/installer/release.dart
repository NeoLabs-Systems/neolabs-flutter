import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:http/http.dart' as http;

import 'models.dart';

/// A signed release resolved to this computer's runtime.
class NeoRuntimeRelease {
  const NeoRuntimeRelease({
    required this.version,
    required this.artifact,
    required this.downloadUrl,
  });

  final String version;
  final NeoRuntimeArtifact artifact;
  final String downloadUrl;
}

/// Accepts the raw 32 byte key or its SPKI form.
List<int> decodeRuntimeSigningPublicKey(String publicKeyBase64) {
  final decoded = base64Decode(publicKeyBase64.trim());
  if (decoded.length < 32) {
    throw const FormatException('The signing key must be an Ed25519 key.');
  }
  return decoded.sublist(decoded.length - 32);
}

Future<void> verifyRuntimeManifestSignature({
  required NeoRuntimeApp app,
  required List<int> manifestBytes,
  required String signatureBase64,
}) async {
  late final SimplePublicKey publicKey;
  try {
    publicKey = SimplePublicKey(
      decodeRuntimeSigningPublicKey(app.publicKey),
      type: KeyPairType.ed25519,
    );
  } on Object {
    throw app.fail(
      'SETUP_TRUST_NOT_CONFIGURED',
      NeoInstallText.trustNotConfigured,
      retryable: false,
    );
  }
  var valid = false;
  try {
    valid = await Ed25519().verify(
      manifestBytes,
      signature: Signature(
        base64Decode(signatureBase64.trim()),
        publicKey: publicKey,
      ),
    );
  } on Object {
    valid = false;
  }
  if (!valid) {
    throw app.fail(
      'SETUP_MANIFEST_SIGNATURE_INVALID',
      NeoInstallText.signatureInvalid,
      retryable: false,
    );
  }
}

/// Reads a verified manifest and picks the runtime for this computer.
({String version, NeoRuntimeArtifact artifact}) selectRuntimeArtifact(
  NeoRuntimeApp app,
  List<int> manifestBytes, {
  required String platform,
  required String architecture,
}) {
  NeoInstallerException invalid() => app.fail(
    'SETUP_MANIFEST_INVALID',
    NeoInstallText.manifestInvalid,
    retryable: false,
  );
  Object? decoded;
  try {
    decoded = jsonDecode(utf8.decode(manifestBytes));
  } on FormatException {
    throw invalid();
  }
  if (decoded is! Map) throw invalid();
  final version = decoded['version']?.toString().trim() ?? '';
  final artifacts = decoded['artifacts'];
  if (int.tryParse('${decoded['schemaVersion']}') != app.schemaVersion ||
      !RegExp(r'^[0-9A-Za-z][0-9A-Za-z.+_-]*$').hasMatch(version) ||
      artifacts is! List) {
    throw invalid();
  }
  final supported = app.targets[platform]?.contains(architecture) ?? false;
  for (final entry in supported ? artifacts.whereType<Map>() : const <Map>[]) {
    if (entry['platform'] != platform ||
        entry['architecture'] != architecture) {
      continue;
    }
    final assetName = entry['assetName']?.toString().trim() ?? '';
    final sha256 = entry['sha256']?.toString().trim().toLowerCase() ?? '';
    final sizeBytes = int.tryParse('${entry['sizeBytes']}') ?? 0;
    if (!RegExp(r'^[0-9A-Za-z][0-9A-Za-z._-]*$').hasMatch(assetName) ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(sha256) ||
        sizeBytes <= 0) {
      throw invalid();
    }
    return (
      version: version,
      artifact: NeoRuntimeArtifact(
        assetName: assetName,
        sha256: sha256,
        sizeBytes: sizeBytes,
      ),
    );
  }
  throw app.fail(
    'SETUP_PLATFORM_UNSUPPORTED',
    NeoInstallText.unsupportedPlatform,
    retryable: false,
  );
}

class NeoRuntimeReleaseService {
  NeoRuntimeReleaseService({
    required this.app,
    required http.Client client,
    required void Function() checkCancelled,
    required void Function(double progress) onDownloadProgress,
    Uri? releases,
  }) : _client = client,
       _checkCancelled = checkCancelled,
       _onDownloadProgress = onDownloadProgress,
       _releases =
           releases ??
           Uri.https(
             'api.github.com',
             '/repos/${app.repository}/releases',
             const <String, String>{'per_page': '20'},
           );

  static const int _metadataLimitBytes = 2 * 1024 * 1024;
  static const int _signatureLimitBytes = 8192;

  final NeoRuntimeApp app;
  final http.Client _client;
  final void Function() _checkCancelled;
  final void Function(double progress) _onDownloadProgress;
  final Uri _releases;

  Uri _secure(String value) {
    final uri = Uri.tryParse(value);
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
      throw app.fail(
        'SETUP_DOWNLOAD_URL_INVALID',
        NeoInstallText.insecureDownload,
        retryable: false,
      );
    }
    return uri;
  }

  Map<String, String> _headers({bool api = false}) => <String, String>{
    'Accept': api ? 'application/vnd.github+json' : 'application/octet-stream',
    'User-Agent': '${app.name} desktop installer',
    if (api && app.githubToken.trim().isNotEmpty)
      'Authorization': 'Bearer ${app.githubToken.trim()}',
  };

  Future<NeoRuntimeRelease> prepare({
    required String platform,
    required String architecture,
    required String channel,
  }) async {
    final assets = await _resolve(channel);
    _checkCancelled();
    final manifestName = assets.manifest;
    final manifestBytes = await _bytes(
      _secure(assets.urls[manifestName]!),
      _metadataLimitBytes,
    );
    final signature = utf8
        .decode(
          await _bytes(
            _secure(assets.urls['$manifestName.sig']!),
            _signatureLimitBytes,
          ),
        )
        .trim();
    await verifyRuntimeManifestSignature(
      app: app,
      manifestBytes: manifestBytes,
      signatureBase64: signature,
    );
    final selected = selectRuntimeArtifact(
      app,
      manifestBytes,
      platform: platform,
      architecture: architecture,
    );
    final url = assets.urls[selected.artifact.assetName];
    if (url == null) {
      throw app.fail(
        'SETUP_RUNTIME_ASSET_MISSING',
        NeoInstallText.assetMissing,
      );
    }
    return NeoRuntimeRelease(
      version: selected.version,
      artifact: selected.artifact,
      downloadUrl: url,
    );
  }

  Future<({String manifest, Map<String, String> urls})> _resolve(
    String channel,
  ) async {
    final bytes = await _bytes(
      _releases,
      _metadataLimitBytes,
      api: true,
      code: 'SETUP_RELEASE_LOOKUP_FAILED',
      text: NeoInstallText.releaseLookupFailed,
    );
    final decoded = jsonDecode(utf8.decode(bytes));
    if (decoded is! List) {
      throw app.fail(
        'SETUP_RELEASE_INVALID',
        NeoInstallText.releaseListInvalid,
      );
    }
    for (final release in decoded.whereType<Map>()) {
      if (release['draft'] == true) continue;
      if (channel != 'beta' && release['prerelease'] == true) continue;
      final urls = <String, String>{
        for (final asset
            in (release['assets'] as List? ?? const <Object>[])
                .whereType<Map>())
          '${asset['name']}': '${asset['browser_download_url']}',
      };
      for (final name in urls.keys) {
        if (name.startsWith(app.manifestPrefix) &&
            name.endsWith('.json') &&
            urls.containsKey('$name.sig')) {
          return (manifest: name, urls: urls);
        }
      }
    }
    throw app.fail('SETUP_RUNTIME_NOT_PUBLISHED', NeoInstallText.notPublished);
  }

  Future<void> downloadArtifact(NeoRuntimeRelease release, File target) async {
    final request = http.Request('GET', _secure(release.downloadUrl))
      ..headers.addAll(_headers());
    final response = await _client.send(request);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw app.fail('SETUP_DOWNLOAD_FAILED', NeoInstallText.downloadFailed);
    }
    final expected = release.artifact.sizeBytes;
    final sink = target.openWrite();
    var received = 0;
    var reported = -1.0;
    try {
      await for (final chunk in response.stream) {
        _checkCancelled();
        sink.add(chunk);
        received += chunk.length;
        if (received > expected) break;
        final progress = received / expected;
        if (progress == 1.0 || progress - reported >= 0.01) {
          reported = progress;
          _onDownloadProgress(progress);
        }
      }
    } finally {
      await sink.close();
    }
    if (received != expected) {
      throw app.fail(
        'SETUP_DOWNLOAD_INCOMPLETE',
        NeoInstallText.downloadIncomplete,
      );
    }
  }

  Future<List<int>> _bytes(
    Uri uri,
    int maxBytes, {
    bool api = false,
    String code = 'SETUP_DOWNLOAD_FAILED',
    NeoInstallText text = NeoInstallText.downloadFailed,
  }) async {
    final request = http.Request('GET', uri)
      ..headers.addAll(_headers(api: api));
    final response = await _client.send(request);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw app.fail(code, text);
    }
    final bytes = <int>[];
    await for (final chunk in response.stream) {
      _checkCancelled();
      if (bytes.length + chunk.length > maxBytes) {
        throw app.fail(
          'SETUP_DOWNLOAD_TOO_LARGE',
          NeoInstallText.metadataTooLarge,
          retryable: false,
        );
      }
      bytes.addAll(chunk);
    }
    return bytes;
  }
}
