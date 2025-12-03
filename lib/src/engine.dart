import 'dart:ffi' as ffi;
import 'package:wasmtime/src/config.dart';
import 'package:wasmtime/src/third_party/wasmtime.g.dart';

/// Represents a Wasmtime engine.
///
/// An [Engine] is a long-lived object that can be reused for multiple
/// WebAssembly compilations and instantiations.
class Engine {
  /// Creates a new [Engine] with default configuration.
  Engine() : _ptr = wasm_engine_new() {
    if (_ptr == ffi.nullptr) {
      throw Exception('Failed to create wasm_engine_t');
    }
  }

  /// Creates a new [Engine] with the given [Config].
  Engine.withConfig(Config config)
    : _ptr = wasm_engine_new_with_config(config.ptr) {
    if (_ptr == ffi.nullptr) {
      throw Exception('Failed to create wasm_engine_t with config');
    }
    // The engine takes ownership of the config, so invalidate it.
    config.takeOwnership();
  }

  late final ffi.Pointer<wasm_engine_t> _ptr;
  bool _isDisposed = false;

  /// Disposes the [Engine] object.
  ///
  /// This frees the native resources associated with this engine.
  void dispose() {
    if (!_isDisposed) {
      wasm_engine_delete(_ptr);
      _isDisposed = true;
    }
  }

  /// Increments the epoch for epoch-based interruption.
  void incrementEpoch() {
    wasmtime_engine_increment_epoch(_ptr);
  }

  /// Returns whether this engine is using the Pulley interpreter.
  bool get isPulley => wasmtime_engine_is_pulley(_ptr);

  /// Returns the native pointer to the engine.
  ffi.Pointer<wasm_engine_t> get ptr => _ptr;
}
