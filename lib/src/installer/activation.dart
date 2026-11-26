import 'dart:convert';
import 'dart:io';

import 'models.dart';

/// The versioned runtimes under `<home>/app`, in the layout the Go CLIs use.
class NeoRuntimeActivation {
  NeoRuntimeActivation(this.app);

  final NeoRuntimeApp app;

  static String _join(String root, Iterable<String> segments) =>
      <String>[root, ...segments].join(Platform.pathSeparator);

  Directory versionsDirectory(Directory runtimeHome) =>
      Directory(_join(runtimeHome.path, const <String>['app', 'versions']));

  Directory versionDirectory(Directory runtimeHome, String version) =>
      Directory(_join(versionsDirectory(runtimeHome).path, <String>[version]));

  /// The binary of an unpacked runtime: server and CLI in one.
  File executable(Directory version) => File(
    _join(version.path, <String>[
      'app',
      'bin',
      Platform.isWindows ? '${app.command}.exe' : app.command,
    ]),
  );

  void validate(Directory version) {
    final binary = executable(version);
    final web = File(_join(version.path, <String>['app', ...app.webIndex]));
    if (!binary.existsSync() || !web.existsSync()) {
      throw app.fail(
        'SETUP_RUNTIME_INCOMPLETE',
        NeoInstallText.runtimeIncomplete,
        retryable: false,
      );
    }
    _restorePermissions(version, binary);
  }

  bool isComplete(Directory version) {
    try {
      validate(version);
      return true;
    } on NeoInstallerException {
      return false;
    }
  }

  void _restorePermissions(Directory version, File binary) {
    if (Platform.isWindows) return;
    void allow(File file) {
      final result = Process.runSync('chmod', <String>[
        'u+rwx,go+rx',
        file.path,
      ]);
      if (result.exitCode != 0) {
        throw app.fail(
          'SETUP_RUNTIME_INCOMPLETE',
          NeoInstallText.runtimeIncomplete,
          retryable: false,
        );
      }
    }

    allow(binary);
    for (final directory in <Directory>[
      binary.parent,
      for (final segments in app.extraBinDirectories)
        Directory(_join(version.path, <String>['app', ...segments])),
    ]) {
      if (!directory.existsSync()) continue;
      directory.listSync().whereType<File>().forEach(allow);
    }
  }

  File _marker(Directory runtimeHome) =>
      File(_join(runtimeHome.path, const <String>['app', 'current.json']));

  String? currentVersion(Directory runtimeHome) {
    try {
      final decoded = jsonDecode(_marker(runtimeHome).readAsStringSync());
      if (decoded is! Map) return null;
      final version = decoded['version']?.toString().trim() ?? '';
      return RegExp(r'^[0-9A-Za-z.+_-]+$').hasMatch(version) ? version : null;
    } on Object {
      return null;
    }
  }

  /// Makes `version` the active one and returns the previous one.
  Future<String?> activate(Directory runtimeHome, String version) async {
    final previous = currentVersion(runtimeHome);
    await _write(runtimeHome, version);
    return previous;
  }

  /// Points back at the previous runtime, or at none.
  Future<void> restore(Directory runtimeHome, String? previous) async {
    if (previous != null) return _write(runtimeHome, previous);
    final marker = _marker(runtimeHome);
    if (marker.existsSync()) marker.deleteSync();
  }

  Future<void> _write(Directory runtimeRoot, String version) async {
    final appDirectory = Directory(
      _join(runtimeRoot.path, const <String>['app']),
    );
    appDirectory.createSync(recursive: true);
    final current = _marker(runtimeRoot);
    final uniqueSuffix =
        '${pid}_${DateTime.now().microsecondsSinceEpoch.toRadixString(16)}';
    final temporary = File('${current.path}.$uniqueSuffix.tmp');
    final backup = File('${current.path}.$uniqueSuffix.backup');
    await temporary.writeAsString(
      '${jsonEncode(<String, dynamic>{'schemaVersion': app.schemaVersion, 'version': version, 'activatedAt': DateTime.now().toUtc().toIso8601String()})}\n',
      flush: true,
    );
    try {
      try {
        await temporary.rename(current.path);
      } on FileSystemException {
        if (!await current.exists()) rethrow;
        await current.rename(backup.path);
        try {
          await temporary.rename(current.path);
          try {
            await backup.delete();
          } on FileSystemException {
            // Activation succeeded; a stale backup is safe to remove later.
          }
        } on Object {
          if (!await current.exists() && await backup.exists()) {
            await backup.rename(current.path);
          }
          rethrow;
        }
      }
    } finally {
      try {
        if (await temporary.exists()) await temporary.delete();
      } on FileSystemException {
        // The next installer run can safely remove an inactive staging marker.
      }
    }
  }
}
