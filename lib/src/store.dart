import 'dart:ffi' as ffi;
import 'package:wasmtime/src/engine.dart';
import 'package:wasmtime/src/third_party/wasmtime.g.dart';

/// Represents a Wasmtime store.
///
/// A [Store] is a collection of WebAssembly instances and host-defined state.
/// All WebAssembly instances and items are attached to a [Store].
class Store {
  /// Creates a new [Store] within the given [Engine].
  Store(Engine engine) {
    // For now, we don't support passing custom data or a finalizer.
    _ptr = wasmtime_store_new(engine.ptr, ffi.nullptr, ffi.nullptr);
    if (_ptr == ffi.nullptr) {
      throw Exception('Failed to create wasmtime_store_t');
    }
    _context = wasmtime_store_context(_ptr);
  }

  late final ffi.Pointer<wasmtime_store> _ptr;
  late final ffi.Pointer<wasmtime_context> _context;
  bool _isDisposed = false;

  /// Disposes the [Store] object.
  ///
  /// This frees the native resources associated with this store.
  void dispose() {
    if (!_isDisposed) {
      wasmtime_store_delete(_ptr);
      _isDisposed = true;
    }
  }

  /// Performs garbage collection within the store.
  ///
  /// This cleans up any `externref` values that are no longer referenced.
  void gc() {
    wasmtime_context_gc(_context);
  }

  /// Returns the native pointer to the store.
  ffi.Pointer<wasmtime_store> get ptr => _ptr;

  /// Returns the native pointer to the store context.
  ffi.Pointer<wasmtime_context> get context => _context;
}
