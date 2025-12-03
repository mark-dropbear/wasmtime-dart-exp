import 'dart:ffi' as ffi;
import 'package:ffi/ffi.dart';
import 'package:wasmtime/src/third_party/wasmtime.g.dart';

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

  // Ensure union is 24 bytes (size of anyref/externref)
  @ffi.Array(24)
  external ffi.Array<ffi.Uint8> _padding;
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
  external ffi.Array<ffi.Uint8> _padding;
}

final class WasmtimeExtern extends ffi.Struct {
  @ffi.Uint8()
  external int kind;

  // Padding to align 'of' to 8 bytes.
  @ffi.Array(7)
  external ffi.Array<ffi.Uint8> _padding;

  external WasmtimeExternUnion of;
}

final class WasmtimeVal extends ffi.Struct {
  @ffi.Uint8()
  external int kind;

  // Padding to align 'of' to 8 bytes.
  // kind is 1 byte. We need 7 bytes padding.
  @ffi.Array(7)
  external ffi.Array<ffi.Uint8> _padding;

  external WasmtimeValUnion of;
}

class Val {
  final ValKind kind;
  final Object? value;

  Val.i32(int val) : kind = ValKind.i32, value = val;
  Val.i64(int val) : kind = ValKind.i64, value = val;
  Val.f32(double val) : kind = ValKind.f32, value = val;
  Val.f64(double val) : kind = ValKind.f64, value = val;
  // TODO: Implement ref types

  static Val fromNative(WasmtimeVal native) {
    final kind = ValKind.fromValue(native.kind);
    switch (kind) {
      case ValKind.i32:
        return Val.i32(native.of.i32);
      case ValKind.i64:
        return Val.i64(native.of.i64);
      case ValKind.f32:
        return Val.f32(native.of.f32);
      case ValKind.f64:
        return Val.f64(native.of.f64);
      default:
        // TODO: Handle ref types
        return Val.i32(0); // Placeholder
    }
  }

  void toNative(ffi.Pointer<WasmtimeVal> ptr) {
    ptr.ref.kind = kind.value;
    switch (kind) {
      case ValKind.i32:
        ptr.ref.of.i32 = value as int;
        break;
      case ValKind.i64:
        ptr.ref.of.i64 = value as int;
        break;
      case ValKind.f32:
        ptr.ref.of.f32 = value as double;
        break;
      case ValKind.f64:
        ptr.ref.of.f64 = value as double;
        break;
      default:
        // TODO: Handle ref types
        break;
    }
  }

  @override
  String toString() => 'Val($kind, $value)';
}

class Trap {
  final ffi.Pointer<wasm_trap_t> _ptr;

  Trap._(this._ptr);

  factory Trap.fromPtr(ffi.Pointer<wasm_trap_t> ptr) => Trap._(ptr);

  ffi.Pointer<wasm_trap_t> get ptr => _ptr;

  String get message {
    final byteVec = calloc<wasm_byte_vec_t>();
    try {
      wasm_trap_message(_ptr, byteVec);
      // wasm_byte_vec_t has size and data.
      // data is Pointer<Char>.
      // We need to read it as string.
      // The string might not be null-terminated?
      // wasm_byte_vec_t usually contains a string that is not null-terminated but size is given.
      // But wait, generated bindings for wasm_byte_vec_t:
      // external int size;
      // external ffi.Pointer<ffi.Char> data;
      if (byteVec.ref.data == ffi.nullptr) return '';
      final str = byteVec.ref.data.cast<ffi.Uint8>().asTypedList(
        byteVec.ref.size,
      );
      return String.fromCharCodes(str); // Assuming UTF-8/ASCII? usually UTF-8.
    } finally {
      wasm_byte_vec_delete(byteVec);
      calloc.free(byteVec);
    }
  }

  void dispose() {
    wasm_trap_delete(_ptr);
  }
}
