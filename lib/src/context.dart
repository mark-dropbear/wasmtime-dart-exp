import 'dart:ffi' as ffi;
import 'package:wasmtime/src/third_party/wasmtime.g.dart';

/// An interface for objects that provide a Wasmtime context.
abstract class WasmContext {
  /// Returns the native pointer to the Wasmtime context.
  ffi.Pointer<wasmtime_context> get context;
}
