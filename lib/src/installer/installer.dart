import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

import 'activation.dart';
// A web build imports this library's types but never installs anything.
import 'architecture_stub.dart' if (dart.library.ffi) 'architecture_ffi.dart';
import 'archive.dart';
import 'models.dart';
import 'release.dart';

/// Downloads the signed server runtime for this computer, verifies and unpacks
/// it, makes it the active one and lets the app configure it. If configuring
/// fails, the previous runtime is put back.
class NeoRuntimeInstaller {
  NeoRuntimeInstaller({
    required this.app,
    required void Function(NeoInstallEvent event) onEvent,
    http.Client? client,
    Uri? releases,
  }) : _onEvent = onEvent,
       _client = client ?? http.Client(),
       activation = NeoRuntimeActivation(app) {
    _releases = NeoRuntimeReleaseService(
      app: app,
      client: _client,
      releases: releases,
      checkCancelled: throwIfCancelled,
      onDownloadProgress: (progress) => _emit(
        NeoInstallStage.download,
        'progress',
        NeoInstallText.downloading,
        0.12 + progress * 0.36,
      ),
    );
  }

  final NeoRuntimeApp app;
  final NeoRuntimeActivation activation;
  final void Function(NeoInstallEvent event) _onEvent;
  final http.Client _client;
  late final NeoRuntimeReleaseService _releases;
  bool _cancelled = false;
  bool _disposed = false;

  bool get cancelled => _cancelled;

  /// `configure` runs the unpacked binary. `rollbackArguments` is what the
  /// restored (or, without one, the failed) binary is then asked to do.
  Future<T> install<T>({
    required String channel,
    required Directory runtimeHome,
    required Future<T> Function(Directory version, File executable) configure,
    required List<String> Function(bool hasPrevious) rollbackArguments,
    Map<String, String> environment = const <String, String>{},
  }) async {
    if (_disposed) {
      throw app.fail(
        'SETUP_INSTALLER_DISPOSED',
        NeoInstallText.disposed,
        retryable: false,
      );
    }
    _cancelled = false;
    Directory? staging;
    try {
      _emit(NeoInstallStage.prepare, 'started', NeoInstallText.finding, 0.02);
      final release = await _releases.prepare(
        platform: _platform(),
        architecture: hostArchitecture(),
        channel: channel,
      );
      final versions = activation.versionsDirectory(runtimeHome);
      final target = activation.versionDirectory(runtimeHome, release.version);
      _deleteOrphanStaging(versions);
      if (activation.isComplete(target)) {
        _emit(
          NeoInstallStage.install,
          'started',
          NeoInstallText.usingInstalled,
          0.7,
        );
      } else {
        versions.createSync(recursive: true);
        staging = await versions.createTemp('.staging-');
        await _unpack(release, staging, target);
      }
      final previous = await activation.activate(runtimeHome, release.version);
      throwIfCancelled();
      try {
        final result = await configure(target, activation.executable(target));
        _emit(NeoInstallStage.complete, 'completed', NeoInstallText.ready, 1);
        return result;
      } on Object {
        await _rollback(
          runtimeHome: runtimeHome,
          failed: release.version,
          previous: previous,
          arguments: rollbackArguments(previous != null),
          environment: environment,
        );
        rethrow;
      }
    } on NeoInstallerException catch (error) {
      _failed(error);
      rethrow;
    } on Object catch (error) {
      final wrapped = NeoInstallerException('SETUP_INSTALL_FAILED', '$error');
      _failed(wrapped);
      throw wrapped;
    } finally {
      try {
        if (staging != null && staging.existsSync()) {
          staging.deleteSync(recursive: true);
        }
      } on FileSystemException {
        // The next run removes orphaned staging directories.
      }
    }
  }

  Future<void> _unpack(
    NeoRuntimeRelease release,
    Directory staging,
    Directory target,
  ) async {
    final archive = File(
      '${staging.path}${Platform.pathSeparator}${release.artifact.assetName}',
    );
    _emit(
      NeoInstallStage.download,
      'started',
      NeoInstallText.downloading,
      0.12,
    );
    await _releases.downloadArtifact(release, archive);
    throwIfCancelled();
    _emit(NeoInstallStage.verify, 'started', NeoInstallText.verifying, 0.5);
    final digest = await sha256.bind(archive.openRead()).first;
    if ('$digest' != release.artifact.sha256) {
      throw app.fail(
        'SETUP_RUNTIME_HASH_MISMATCH',
        NeoInstallText.hashMismatch,
      );
    }
    final extracted = Directory(
      '${staging.path}${Platform.pathSeparator}extracted',
    )..createSync(recursive: true);
    _emit(NeoInstallStage.install, 'started', NeoInstallText.extracting, 0.58);
    // Unpacking reports nothing, so the bar creeps while it runs.
    var progress = 0.58;
    final ticker = Timer.periodic(const Duration(seconds: 2), (_) {
      if (_cancelled) return;
      progress = (progress + 0.008).clamp(0.58, 0.69);
      _emit(
        NeoInstallStage.install,
        'progress',
        NeoInstallText.extracting,
        progress,
      );
    });
    try {
      await extractVerifiedRuntimeArchive(app, archive.path, extracted.path);
    } finally {
      ticker.cancel();
    }
    activation.validate(extracted);
    // An incomplete leftover of this version is replaced.
    if (target.existsSync()) target.deleteSync(recursive: true);
    extracted.renameSync(target.path);
  }

  Future<void> _rollback({
    required Directory runtimeHome,
    required String failed,
    required String? previous,
    required List<String> arguments,
    required Map<String, String> environment,
  }) async {
    _emit(NeoInstallStage.install, 'rollback', NeoInstallText.restoring, null);
    await activation.restore(runtimeHome, previous);
    final version = activation.versionDirectory(
      runtimeHome,
      previous ?? failed,
    );
    try {
      await Process.run(
        activation.executable(version).path,
        arguments,
        environment: <String, String>{...Platform.environment, ...environment},
        workingDirectory: '${version.path}${Platform.pathSeparator}app',
      ).timeout(const Duration(seconds: 45));
    } on Object {
      _onEvent(
        NeoInstallEvent(
          stage: NeoInstallStage.install,
          state: 'message',
          message: app.strings(NeoInstallText.rollbackIncomplete),
          errorCode: 'SETUP_ROLLBACK_INCOMPLETE',
        ),
      );
    }
  }

  void _deleteOrphanStaging(Directory versions) {
    if (!versions.existsSync()) return;
    for (final entity in versions.listSync(followLinks: false)) {
      final name = entity.path.split(Platform.pathSeparator).last;
      if (entity is! Directory || !name.startsWith('.staging-')) continue;
      try {
        entity.deleteSync(recursive: true);
      } on FileSystemException {
        // A leftover staging directory is removed on a later run.
      }
    }
  }

  String _platform() {
    if (Platform.isMacOS) return 'macos';
    if (Platform.isWindows) return 'windows';
    if (Platform.isLinux) return 'linux';
    throw app.fail(
      'SETUP_PLATFORM_UNSUPPORTED',
      NeoInstallText.unsupportedPlatform,
      retryable: false,
    );
  }

  void _emit(
    NeoInstallStage stage,
    String state,
    NeoInstallText text,
    double? progress,
  ) => _onEvent(
    NeoInstallEvent(
      stage: stage,
      state: state,
      message: app.strings(text),
      progress: progress,
    ),
  );

  void _failed(NeoInstallerException error) => _onEvent(
    NeoInstallEvent(
      stage: NeoInstallStage.install,
      state: 'failed',
      message: error.message,
      errorCode: error.code,
      retryable: error.retryable,
    ),
  );

  void throwIfCancelled() {
    if (_cancelled) {
      throw app.fail('SETUP_CANCELLED', NeoInstallText.cancelled);
    }
  }

  void cancel() => _cancelled = true;

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    cancel();
    _client.close();
  }
}
