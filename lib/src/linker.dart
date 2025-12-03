import 'dart:ffi' as ffi;

import 'package:ffi/ffi.dart';
import 'package:wasmtime/src/engine.dart';
import 'package:wasmtime/src/extern.dart';
import 'package:wasmtime/src/instance.dart';
import 'package:wasmtime/src/module.dart';
import 'package:wasmtime/src/store.dart';
import 'package:wasmtime/src/third_party/wasmtime.g.dart';

/// A linker for WebAssembly modules.
class Linker {
  late final ffi.Pointer<wasmtime_linker> _ptr;
  bool _isDisposed = false;

  /// Creates a new [Linker] for the given [Engine].
  Linker(Engine engine) {
    _ptr = wasmtime_linker_new(engine.ptr);
  }

  /// Disposes of the [Linker].
  void dispose() {
    if (!_isDisposed) {
      wasmtime_linker_delete(_ptr);
      _isDisposed = true;
    }
  }

  /// Configures whether shadowing is allowed in the linker.
  void allowShadowing({required bool allow}) {
    wasmtime_linker_allow_shadowing(_ptr, allow);
  }

  /// Defines a module in the linker with the given name.
  void defineModule(Store store, String name, Module module) {
    final namePtr = name.toNativeUtf8();
    try {
      final error = wasmtime_linker_module(
        _ptr,
        store.context,
        namePtr.cast(),
        name.length,
        module.ptr,
      );
      if (error != ffi.nullptr) {
        // TODO: Handle error
        throw Exception('Failed to define module');
      }
    } finally {
      calloc.free(namePtr);
    }
  }

  /// Defines WASI functions in the linker.
  void defineWasi() {
    final error = wasmtime_linker_define_wasi(_ptr);
    if (error != ffi.nullptr) {
      // TODO: Handle error
      throw Exception('Failed to define WASI');
    }
  }

  /// Defines an extern in the linker.
  void define(Store store, String module, String name, Extern item) {
    final modulePtr = module.toNativeUtf8();
    final namePtr = name.toNativeUtf8();
    try {
      final error = wasmtime_linker_define(
        _ptr,
        store.context,
        modulePtr.cast(),
        module.length,
        namePtr.cast(),
        name.length,
        item.ptr.cast(),
      );
      if (error != ffi.nullptr) {
        // TODO: Handle error
        throw Exception('Failed to define extern');
      }
    } finally {
      calloc.free(modulePtr);
      calloc.free(namePtr);
    }
  }

  /// Instantiates a module using the linker.
  Instance instantiate(Store store, Module module) {
    // wasmtime_instance_t is 16 bytes on 64-bit (uint64_t + size_t).
    // We allocate enough space for it.
    final instancePtr = calloc<ffi.Uint8>(16).cast<wasmtime_instance>();
    final trapPtr = calloc<ffi.Pointer<wasm_trap_t>>();

    try {
      final error = wasmtime_linker_instantiate(
        _ptr,
        store.context,
        module.ptr,
        instancePtr,
        trapPtr,
      );

      if (error != ffi.nullptr) {
        // TODO: Handle error
        throw Exception('Failed to instantiate module');
      }

      if (trapPtr.value != ffi.nullptr) {
        // TODO: Handle trap
        throw Exception('Trap during instantiation');
      }

      return Instance.fromPtr(instancePtr);
    } catch (e) {
      calloc.free(instancePtr);
      rethrow;
    } finally {
      calloc.free(trapPtr);
    }
  }
}
