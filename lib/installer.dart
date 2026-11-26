/// Installs a NeoLabs server on this computer from its signed runtime. A
/// separate library because it needs `dart:io`, so web builds do not load it.
library;

export 'src/installer/activation.dart';
export 'src/installer/archive.dart';
export 'src/installer/installer.dart';
export 'src/installer/models.dart';
export 'src/installer/release.dart';
