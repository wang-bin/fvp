import 'dart:ffi';

import 'package:ffi/ffi.dart';

extension NullTerminatedU8PtrArray on Pointer<Pointer<Utf8>> {
  void free() {
    for (int i = 0;; ++i) {
      final p = this[i];
      if (p == nullptr) { // FIXME: why sometimes the last element is not null?
        break;
      }
      //print('free at $i = $p');
      malloc.free(p);
    }
    calloc.free(this);
  }
}

extension CStringList on List<String> {
  Pointer<Pointer<Utf8>> toC() {
    List<Pointer<Utf8>> ul = map((s) => s.toNativeUtf8()).toList();

    final pp = calloc.allocate<Pointer<Utf8>>(ul.length);
    //final Pointer<Pointer<Utf8>> pp = calloc.allocate(ul.length * sizeOf<Pointer<Utf8>>());

    asMap().forEach((index, _) {
      pp[index] = ul[index];
    });
    return pp;
  }

  Pointer<Pointer<Utf8>> toCZ() {
    List<Pointer<Utf8>> ul = map((s) => s.toNativeUtf8()).toList();

    final pp = calloc.allocate<Pointer<Utf8>>(ul.length + 1);

    for (int i = 0; i < length; ++i) {
      pp[i] = ul[i];
    }
    pp[ul.length] = nullptr; // optional if use calloc?
    return pp;
  }
}
