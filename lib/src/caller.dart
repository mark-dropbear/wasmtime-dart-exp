import 'dart:ffi' as ffi;
import 'package:ffi/ffi.dart';
import 'package:wasmtime/src/context.dart';
import 'package:wasmtime/src/extern.dart';
import 'package:wasmtime/src/third_party/wasmtime.g.dart';
import 'package:wasmtime/src/types.dart';

/// Represents the caller of a host function.
///
/// This class provides access to the exports of the calling module and the
/// store context.
class Caller implements WasmContext {
  final ffi.Pointer<wasmtime_caller> _ptr;

  Caller._(this._ptr);

  /// Creates a [Caller] from a raw pointer.
  factory Caller.fromPtr(ffi.Pointer<wasmtime_caller> ptr) => Caller._(ptr);

  @override
  ffi.Pointer<wasmtime_context> get context => wasmtime_caller_context(_ptr);

  /// Retrieves an exported item from the caller by name.
  Extern? getExport(String name) {
    final namePtr = name.toNativeUtf8();
    final itemPtr = calloc<WasmtimeExtern>();

    var found = false;
    try {
      found = wasmtime_caller_export_get(
        _ptr,
        namePtr.cast(),
        name.length,
        itemPtr.cast(),
      );

      if (found) {
        return Extern.fromNative(itemPtr);
      }
      return null;
    } finally {
      calloc.free(namePtr);
      if (!found) {
        calloc.free(itemPtr);
      }
    }
  }
}
