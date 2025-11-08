// ignore_for_file: non_constant_identifier_names

import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:wasmtime/src/wasmtime_bindings.dart';

@Native<Pointer<wasm_engine_t> Function()>(
  assetId: 'package:wasmtime/libwasmtime',
)
external Pointer<wasm_engine_t> wasm_engine_new();

@Native<Void Function(Pointer<wasm_engine_t>)>(
  assetId: 'package:wasmtime/libwasmtime',
)
external void wasm_engine_delete(Pointer<wasm_engine_t> engine);

@Native<
  Pointer<wasmtime_error_t> Function(
    Pointer<Char>,
    IntPtr,
    Pointer<wasm_byte_vec_t>,
  )
>(assetId: 'package:wasmtime/libwasmtime')
external Pointer<wasmtime_error_t> wasmtime_wat2wasm(
  Pointer<Char> wat,
  int wat_len,
  Pointer<wasm_byte_vec_t> ret,
);

@Native<Void Function(Pointer<wasmtime_error_t>, Pointer<wasm_name_t>)>(
  assetId: 'package:wasmtime/libwasmtime',
)
external void wasmtime_error_message(
  Pointer<wasmtime_error_t> error,
  Pointer<wasm_name_t> message,
);

@Native<Void Function(Pointer<wasmtime_error_t>)>(
  assetId: 'package:wasmtime/libwasmtime',
)
external void wasmtime_error_delete(Pointer<wasmtime_error_t> error);

@Native<Void Function(Pointer<wasm_byte_vec_t>)>(
  assetId: 'package:wasmtime/libwasmtime',
)
external void wasm_byte_vec_delete(Pointer<wasm_byte_vec_t> vec);

class Wasmtime {
  WasmtimeWat2WasmResult wasmtimeWat2Wasm(String wat) {
    final watPtr = wat.toNativeUtf8();
    final wasmPtr = calloc<wasm_byte_vec_t>();
    final error = wasmtime_wat2wasm(watPtr.cast(), wat.length, wasmPtr);

    if (error != nullptr) {
      final errorMsgVec = calloc<wasm_name_t>();
      wasmtime_error_message(error, errorMsgVec);
      final errorMessage = errorMsgVec.ref.data.cast<Utf8>().toDartString(
        length: errorMsgVec.ref.size,
      );
      wasm_byte_vec_delete(errorMsgVec);
      wasmtime_error_delete(error);
      calloc.free(watPtr);
      calloc.free(wasmPtr);
      throw WasmtimeException(errorMessage);
    }

    final wasmBytes = wasmPtr.ref.data.cast<Uint8>().asTypedList(
      wasmPtr.ref.size,
    );
    calloc.free(watPtr);
    wasm_byte_vec_delete(wasmPtr);
    calloc.free(wasmPtr);

    return WasmtimeWat2WasmResult(wasmBytes);
  }
}

class WasmtimeWat2WasmResult {
  final List<int> wasmBytes;

  WasmtimeWat2WasmResult(this.wasmBytes);
}

class WasmtimeException implements Exception {
  final String message;

  WasmtimeException(this.message);

  @override
  String toString() => 'WasmtimeException: $message';
}
