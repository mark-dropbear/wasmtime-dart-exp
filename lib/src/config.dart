import 'dart:ffi' as ffi;
import 'package:wasmtime/src/third_party/wasmtime.g.dart';

/// Represents a Wasmtime configuration.
///
/// A [Config] object is used to configure an [Engine].
class Config {
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
}
