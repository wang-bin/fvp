import 'dart:ffi';
import 'dart:io';
import 'generated_bindings.dart';

abstract class Libmdk {
  static DynamicLibrary _load() {
    const name = {
      'windows': 'mdk.dll',
      'macos': 'mdk.framework/mdk',
      'ios': 'mdk.framework/mdk',
      'linux': 'libmdk.so.0',
      'android': 'libmdk.so',
    };
    if (!name.containsKey(Platform.operatingSystem)) {
      throw Exception(
        'Unsupported operating system: ${Platform.operatingSystem}.',
      );
    }
    try {
      return DynamicLibrary.open(name[Platform.operatingSystem]!);
    } catch(e) {
      rethrow;
    }
  }

  static final instance = NativeLibrary(_load());
}