/// The stages of a local server install, in order.
enum NeoInstallStage {
  prepare,
  download,
  verify,
  install,
  service,
  connect,
  complete,
}

class NeoInstallEvent {
  const NeoInstallEvent({
    required this.stage,
    required this.state,
    required this.message,
    this.progress,
    this.errorCode,
    this.retryable = true,
  });

  final NeoInstallStage stage;

  /// `started`, `progress`, `completed`, `warning`, `message`, or `failed`.
  final String state;
  final String message;
  final double? progress;
  final String? errorCode;
  final bool retryable;
}

class NeoInstallerException implements Exception {
  const NeoInstallerException(this.code, this.message, {this.retryable = true});

  final String code;
  final String message;
  final bool retryable;

  @override
  String toString() => message;
}

/// Everything the installer says. The app supplies it in its own language.
enum NeoInstallText {
  finding,
  downloading,
  verifying,
  extracting,
  usingInstalled,
  ready,
  cancelled,
  disposed,
  unsupportedPlatform,
  insecureDownload,
  releaseLookupFailed,
  releaseListInvalid,
  notPublished,
  assetMissing,
  downloadFailed,
  downloadIncomplete,
  metadataTooLarge,
  trustNotConfigured,
  signatureInvalid,
  manifestInvalid,
  hashMismatch,
  archiveInvalid,
  archiveUnsafe,
  runtimeIncomplete,
  restoring,
  rollbackIncomplete,
}

typedef NeoInstallStrings = String Function(NeoInstallText text);

/// What differs between the apps whose server this installs.
class NeoRuntimeApp {
  const NeoRuntimeApp({
    required this.name,
    required this.command,
    required this.repository,
    required this.publicKey,
    required this.targets,
    required this.webIndex,
    required this.strings,
    this.schemaVersion = 1,
    this.extraBinDirectories = const <List<String>>[],
    this.githubToken = '',
  });

  /// Product name, used in the User-Agent.
  final String name;

  /// Binary and runtime asset name, e.g. `neoagent`.
  final String command;

  /// GitHub `owner/name`.
  final String repository;

  /// Base64 Ed25519 key the runtime manifest must be signed with.
  final String publicKey;

  /// Platform to the architectures that have a runtime.
  final Map<String, List<String>> targets;

  /// The web client's index file inside a runtime, as path segments under
  /// `app/`. A runtime without it is incomplete.
  final List<String> webIndex;
  final NeoInstallStrings strings;
  final int schemaVersion;

  /// Further directories under `app/` whose files must be executable.
  final List<List<String>> extraBinDirectories;
  final String githubToken;

  String get manifestPrefix => '$command-runtime-manifest-';

  NeoInstallerException fail(
    String code,
    NeoInstallText text, {
    bool retryable = true,
  }) => NeoInstallerException(code, strings(text), retryable: retryable);
}

class NeoRuntimeArtifact {
  const NeoRuntimeArtifact({
    required this.assetName,
    required this.sha256,
    required this.sizeBytes,
  });

  final String assetName;
  final String sha256;
  final int sizeBytes;
}
