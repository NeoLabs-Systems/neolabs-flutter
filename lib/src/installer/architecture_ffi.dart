import 'dart:ffi' show Abi;

/// The processor architecture, as release assets spell it.
String hostArchitecture() {
  final abi = Abi.current();
  return abi == Abi.macosArm64 ||
          abi == Abi.linuxArm64 ||
          abi == Abi.windowsArm64
      ? 'arm64'
      : 'x64';
}
