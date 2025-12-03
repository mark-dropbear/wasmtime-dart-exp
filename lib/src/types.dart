import 'dart:ffi' as ffi;

import 'package:wasmtime/src/third_party/wasmtime.g.dart';

// We use C-style naming for FFI structs and constants to match the Wasmtime C API.
// ignore_for_file: non_constant_identifier_names, constant_identifier_names

/// Constant for i32 type.
const int WASMTIME_I32 = 0;

/// Constant for i64 type.
const int WASMTIME_I64 = 1;

/// Constant for f32 type.
const int WASMTIME_F32 = 2;

/// Constant for f64 type.
const int WASMTIME_F64 = 3;

/// Constant for v128 type.
const int WASMTIME_V128 = 4;

/// Constant for funcref type.
const int WASMTIME_FUNCREF = 5;

/// Constant for externref type.
const int WASMTIME_EXTERNREF = 6;

/// Constant for anyref type.
const int WASMTIME_ANYREF = 7;

/// Represents the kind of a WebAssembly value.
enum ValKind {
  /// 32-bit integer.
  i32(WASMTIME_I32),

  /// 64-bit integer.
  i64(WASMTIME_I64),

  /// 32-bit float.
  f32(WASMTIME_F32),

  /// 64-bit float.
  f64(WASMTIME_F64),

  /// 128-bit vector.
  v128(WASMTIME_V128),

  /// Function reference.
  funcref(WASMTIME_FUNCREF),

  /// External reference.
  externref(WASMTIME_EXTERNREF),

  /// Any reference.
  anyref(WASMTIME_ANYREF);

  /// The integer value of the kind.
  final int value;

  const ValKind(this.value);

  /// Creates a [ValKind] from a native integer value.
  static ValKind fromValue(int value) {
    // Handle standard Wasm type kinds
    if (value == 128) return ValKind.externref;
    if (value == 129) return ValKind.funcref;
    // V128 in standard Wasm C API? usually 0x7b (123)
    if (value == 123) return ValKind.v128;

    return ValKind.values.firstWhere(
      (e) => e.value == value,
      orElse: () => throw ArgumentError('Unknown ValKind value: $value'),
    );
  }

  /// Returns the standard Wasm type kind for this [ValKind].
  int toWasmKind() {
    switch (this) {
      case ValKind.i32:
        return 0; // WASM_I32
      case ValKind.i64:
        return 1; // WASM_I64
      case ValKind.f32:
        return 2; // WASM_F32
      case ValKind.f64:
        return 3; // WASM_F64
      case ValKind.externref:
        return 128; // WASM_EXTERNREF
      case ValKind.funcref:
        return 129; // WASM_FUNCREF
      case ValKind.v128:
        return 123; // WASM_V128 (approximate, need verification)
      case ValKind.anyref:
        return 130; // WASM_ANYREF (approximate)
    }
  }
}

/// Union for Wasmtime value data.
final class WasmtimeValUnion extends ffi.Union {
  /// i32 value.
  @ffi.Int32()
  external int i32;

  /// i64 value.
  @ffi.Int64()
  external int i64;

  /// f32 value.
  @ffi.Float()
  external double f32;

  /// f64 value.
  @ffi.Double()
  external double f64;

  /// Reference value (generic/funcref).
  external WasmtimeRefStruct ref;

  /// Externref value.
  external WasmtimeExternRefStruct externref;

  /// Funcref value.
  external WasmtimeFuncStruct funcref;

  /// v128 value.
  external WasmtimeV128 v128;

  // Ensure union is 24 bytes (size of anyref/externref)
  @ffi.Array(24)
  // Padding to ensure the union is 24 bytes, matching the C struct size.
  // ignore: unused_field
  external ffi.Array<ffi.Uint8> _padding;
}

/// Struct for Wasmtime v128 value.
final class WasmtimeV128 extends ffi.Struct {
  /// Low 64 bits.
  @ffi.Uint64()
  external int low;

  /// High 64 bits.
  @ffi.Uint64()
  external int high;
}

/// Struct for Wasmtime externref value.
final class WasmtimeExternRefStruct extends ffi.Struct {
  /// Store ID.
  @ffi.Uint64()
  external int store_id;

  /// Internal private data 1.
  @ffi.Uint32()
  external int private1;

  /// Internal private data 2.
  @ffi.Uint32()
  external int private2;

  /// Internal private data 3.
  external ffi.Pointer<ffi.Void> private3;
}

/// Struct for Wasmtime reference value (generic/funcref).
final class WasmtimeRefStruct extends ffi.Struct {
  /// Store ID.
  @ffi.Uint64()
  external int store_id;

  /// Index or private data.
  @ffi.Uint64()
  external int index;
}

/// Struct for Wasmtime value type vector.
final class WasmValTypeVec extends ffi.Struct {
  /// Size of the vector.
  @ffi.Size()
  external int size;

  /// Pointer to the data.
  external ffi.Pointer<ffi.Pointer<wasm_valtype_t>> data;
}

/// Struct for Wasmtime function.
final class WasmtimeFuncStruct extends ffi.Struct {
  /// Store ID.
  @ffi.Uint64()
  external int store_id;

  /// Private data.
  external ffi.Pointer<ffi.Void> private_data;
}

/// Union for Wasmtime extern data.
final class WasmtimeExternUnion extends ffi.Union {
  /// Function extern.
  external WasmtimeFuncStruct func;

  // Ensure union is 24 bytes (size of global/table/memory/anyref)
  @ffi.Array(24)
  // Padding to ensure the union is 24 bytes, matching the C struct size.
  // ignore: unused_field
  external ffi.Array<ffi.Uint8> _padding;
}

/// Struct for Wasmtime extern.
final class WasmtimeExtern extends ffi.Struct {
  /// Kind of the extern.
  @ffi.Uint8()
  external int kind;

  // Padding to align 'of' to 8 bytes.
  @ffi.Array(7)
  // Padding to align 'of' to 8 bytes.
  // ignore: unused_field
  external ffi.Array<ffi.Uint8> _padding;

  /// The extern data.
  external WasmtimeExternUnion of;
}

/// Struct for Wasmtime value.
final class WasmtimeVal extends ffi.Struct {
  /// Kind of the value.
  @ffi.Uint8()
  external int kind;

  // Padding to align 'of' to 8 bytes.
  // kind is 1 byte. We need 7 bytes padding.
  @ffi.Array(7)
  // Padding to align 'of' to 8 bytes.
  // ignore: unused_field
  external ffi.Array<ffi.Uint8> _padding;

  /// The value data.
  external WasmtimeValUnion of;
}
