import 'dart:ffi' as ffi;

import 'package:wasmtime/src/third_party/wasmtime.g.dart';

// ignore_for_file: non_constant_identifier_names, constant_identifier_names
// We use C-style naming for FFI structs and constants to match the Wasmtime C API.

const int WASMTIME_I32 = 0;
const int WASMTIME_I64 = 1;
const int WASMTIME_F32 = 2;
const int WASMTIME_F64 = 3;
const int WASMTIME_V128 = 4;
const int WASMTIME_FUNCREF = 5;
const int WASMTIME_EXTERNREF = 6;
const int WASMTIME_ANYREF = 7;

enum ValKind {
  i32(WASMTIME_I32),
  i64(WASMTIME_I64),
  f32(WASMTIME_F32),
  f64(WASMTIME_F64),
  v128(WASMTIME_V128),
  funcref(WASMTIME_FUNCREF),
  externref(WASMTIME_EXTERNREF),
  anyref(WASMTIME_ANYREF);

  final int value;
  const ValKind(this.value);

  static ValKind fromValue(int value) {
    return ValKind.values.firstWhere(
      (e) => e.value == value,
      orElse: () => throw ArgumentError('Unknown ValKind value: $value'),
    );
  }
}

final class WasmtimeValUnion extends ffi.Union {
  @ffi.Int32()
  external int i32;

  @ffi.Int64()
  external int i64;

  @ffi.Float()
  external double f32;

  @ffi.Double()
  external double f64;

  external WasmtimeRefStruct ref;
  external WasmtimeV128 v128;

  // Ensure union is 24 bytes (size of anyref/externref)
  @ffi.Array(24)
  // Padding to ensure the union is 24 bytes, matching the C struct size.
  // ignore: unused_field
  external ffi.Array<ffi.Uint8> _padding;
}

final class WasmtimeV128 extends ffi.Struct {
  @ffi.Uint64()
  external int low;
  @ffi.Uint64()
  external int high;
}

final class WasmtimeRefStruct extends ffi.Struct {
  @ffi.Uint64()
  external int store_id;
  @ffi.Uint64()
  external int index; // or __private data
}

final class WasmValTypeVec extends ffi.Struct {
  @ffi.Size()
  external int size;

  external ffi.Pointer<ffi.Pointer<wasm_valtype_t>> data;
}

final class WasmtimeFuncStruct extends ffi.Struct {
  @ffi.Uint64()
  external int store_id;
  external ffi.Pointer<ffi.Void> private_data;
}

final class WasmtimeExternUnion extends ffi.Union {
  external WasmtimeFuncStruct func;

  // Ensure union is 24 bytes (size of global/table/memory/anyref)
  @ffi.Array(24)
  // Padding to ensure the union is 24 bytes, matching the C struct size.
  // ignore: unused_field
  external ffi.Array<ffi.Uint8> _padding;
}

final class WasmtimeExtern extends ffi.Struct {
  @ffi.Uint8()
  external int kind;

  // Padding to align 'of' to 8 bytes.
  @ffi.Array(7)
  // Padding to align 'of' to 8 bytes.
  // ignore: unused_field
  external ffi.Array<ffi.Uint8> _padding;

  external WasmtimeExternUnion of;
}

final class WasmtimeVal extends ffi.Struct {
  @ffi.Uint8()
  external int kind;

  // Padding to align 'of' to 8 bytes.
  // kind is 1 byte. We need 7 bytes padding.
  @ffi.Array(7)
  // Padding to align 'of' to 8 bytes.
  // ignore: unused_field
  external ffi.Array<ffi.Uint8> _padding;

  external WasmtimeValUnion of;
}

// Val class moved to val.dart

// Val class moved to val.dart
// Trap class moved to trap.dart
