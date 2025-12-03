import 'dart:ffi' as ffi;
import 'package:wasmtime/src/context.dart';
import 'package:wasmtime/src/engine.dart';
import 'package:wasmtime/src/third_party/wasmtime.g.dart';

/// Represents a Wasmtime store.
class Store implements WasmContext {
  final ffi.Pointer<wasmtime_store> _ptr;

  /// Creates a new [Store] with the given [Engine].
  Store(Engine engine)
    : _ptr = wasmtime_store_new(engine.ptr, ffi.nullptr, ffi.nullptr);

  /// Disposes of the [Store].
  void dispose() {
    wasmtime_store_delete(_ptr);
  }

  /// Returns the native pointer to the store.
  ffi.Pointer<wasmtime_store> get ptr => _ptr;

  /// Returns the native pointer to the store context.
  @override
  ffi.Pointer<wasmtime_context> get context => wasmtime_store_context(_ptr);

  /// Performs garbage collection within the store.
  void gc() {
    wasmtime_context_gc(context);
  }
}
