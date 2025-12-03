import 'dart:ffi' as ffi;
import 'dart:typed_data';
import 'package:ffi/ffi.dart';
import 'package:wasmtime/src/engine.dart';
import 'package:wasmtime/src/third_party/wasmtime.g.dart';

/// Represents a compiled WebAssembly module.
class Module {
  Module._(this._ptr);

  /// Compiles a WebAssembly module from the given [wat] (WebAssembly Text) string.
  factory Module.fromText(Engine engine, String wat) {
    final watPtr = wat.toNativeUtf8();
    final wasmBytesPtr = calloc<wasm_byte_vec_t>();

    try {
      final error = wasmtime_wat2wasm(watPtr.cast(), wat.length, wasmBytesPtr);

      if (error != ffi.nullptr) {
        // TODO: Handle error properly
        throw Exception('Failed to convert WAT to WASM');
      }

      return Module.fromBinary(engine, _byteVecToUint8List(wasmBytesPtr));
    } finally {
      calloc.free(watPtr);
      wasm_byte_vec_delete(wasmBytesPtr);
      calloc.free(wasmBytesPtr);
    }
  }

  /// Compiles a WebAssembly module from the given [bytes].
  factory Module.fromBinary(Engine engine, Uint8List bytes) {
    final bytesPtr = calloc<ffi.Uint8>(bytes.length);
    final list = bytesPtr.asTypedList(bytes.length);
    list.setAll(0, bytes);

    final modulePtrPtr = calloc<ffi.Pointer<wasmtime_module>>();

    try {
      final error = wasmtime_module_new(
        engine.ptr,
        bytesPtr,
        bytes.length,
        modulePtrPtr,
      );

      if (error != ffi.nullptr) {
        // TODO: Handle error properly
        throw Exception('Failed to compile module');
      }

      return Module._(modulePtrPtr.value);
    } finally {
      calloc.free(bytesPtr);
      calloc.free(modulePtrPtr);
    }
  }

  late final ffi.Pointer<wasmtime_module> _ptr;
  ffi.Pointer<wasmtime_module> get ptr => _ptr;
  bool _isDisposed = false;

  /// Disposes the [Module] object.
  void dispose() {
    if (!_isDisposed) {
      wasmtime_module_delete(_ptr);
      _isDisposed = true;
    }
  }

  /// Validates that [bytes] is a valid WebAssembly module.
  static void validate(Engine engine, Uint8List bytes) {
    final bytesPtr = calloc<ffi.Uint8>(bytes.length);
    final list = bytesPtr.asTypedList(bytes.length);
    list.setAll(0, bytes);

    try {
      final error = wasmtime_module_validate(
        engine.ptr,
        bytesPtr,
        bytes.length,
      );

      if (error != ffi.nullptr) {
        // TODO: Handle error properly
        throw Exception('Invalid module');
      }
    } finally {
      calloc.free(bytesPtr);
    }
  }

  static Uint8List _byteVecToUint8List(ffi.Pointer<wasm_byte_vec_t> vec) {
    return vec.ref.data.cast<ffi.Uint8>().asTypedList(vec.ref.size);
  }
}
