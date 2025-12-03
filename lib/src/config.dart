import 'dart:ffi' as ffi;
import 'package:wasmtime/src/engine.dart';
import 'package:wasmtime/src/third_party/wasmtime.g.dart';

/// Represents a Wasmtime configuration.
///
/// A [Config] object is used to configure an [Engine].
class Config {
  /// Creates a new [Config] with default settings.
  Config() : _ptr = wasm_config_new() {
    if (_ptr == ffi.nullptr) {
      throw Exception('Failed to create wasm_config_t');
    }
  }

  late final ffi.Pointer<wasm_config_t> _ptr;
  bool _isDisposed = false;

  /// Disposes the [Config] object.
  ///
  /// This frees the native resources associated with this configuration.
  void dispose() {
    if (!_isDisposed) {
      wasm_config_delete(_ptr);
      _isDisposed = true;
    }
  }

  /// Transfers ownership of the native resource.
  ///
  /// This invalidates the native pointer and marks the object as disposed,
  /// preventing further attempts to dispose of it from this [Config] object.
  void takeOwnership() {
    _isDisposed = true;
  }

  /// Returns the native pointer to the configuration.
  ffi.Pointer<wasm_config_t> get ptr => _ptr;
}
