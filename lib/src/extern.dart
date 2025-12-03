import 'dart:ffi' as ffi;
import 'package:ffi/ffi.dart';
import 'package:wasmtime/src/func.dart';
import 'package:wasmtime/src/third_party/wasmtime.g.dart';

import 'package:wasmtime/src/types.dart';

/// Represents an external item (function, global, table, or memory).
class Extern {
  final ffi.Pointer<WasmtimeExtern> _ptr;

  Extern._(this._ptr);

  /// Creates an [Extern] from a raw pointer.
  factory Extern.fromNative(ffi.Pointer<WasmtimeExtern> ptr) => Extern._(ptr);

  /// Disposes of the [Extern].
  void dispose() {
    wasmtime_extern_delete(_ptr.cast());
    calloc.free(_ptr);
  }

  /// Returns the extern as a [Func], or null if it is not a function.
  Func? get asFunc {
    // WASMTIME_EXTERN_FUNC = 0
    if (_ptr.ref.kind == 0) {
      // We need to copy the func handle because Extern might be temporary?
      // Or just return a Func that wraps the pointer in the union.
      // But wasmtime_func_t is a struct, and WasmtimeExternUnion has a pointer?
      // Wait, wasmtime_extern_union_t has wasmtime_func_t func; (by value)
      // So WasmtimeExternUnion should have a struct, not a pointer.
      // But wasmtime_func is Opaque.
      // We can't put Opaque in Union by value in Dart FFI easily if we don't define the struct.
      // But we know wasmtime_func_t is 16 bytes.
      // We can use a byte array or a struct with 2 uint64s.
      // Let's define WasmtimeFuncStruct.
      return Func.fromNative(_ptr.ref.of.func);
    }
    return null;
  }
}
