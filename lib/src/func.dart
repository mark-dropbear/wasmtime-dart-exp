import 'dart:ffi' as ffi;

import 'package:ffi/ffi.dart';
import 'package:wasmtime/src/store.dart';
import 'package:wasmtime/src/third_party/wasmtime.g.dart';
import 'package:wasmtime/src/trap.dart';
import 'package:wasmtime/src/types.dart';
import 'package:wasmtime/src/val.dart';

/// Represents a WebAssembly function.
class Func {
  /// The native pointer to the function.
  final ffi.Pointer<wasmtime_func> ptr;

  Func._(this.ptr);

  /// Creates a [Func] from a native [WasmtimeFuncStruct].
  factory Func.fromNative(WasmtimeFuncStruct native) {
    final ptr = calloc<wasmtime_func>();
    final customPtr = ptr.cast<WasmtimeFuncStruct>();
    customPtr.ref.store_id = native.store_id;
    customPtr.ref.private_data = native.private_data;
    return Func._(ptr);
  }

  /// Disposes of the [Func].
  void dispose() {
    calloc.free(ptr);
  }

  // TODO: Implement from (creating host function)

  /// Calls the function with the given arguments.
  List<Val> call(Store store, List<Val> args) {
    final nargs = args.length;
    final argsPtr = calloc<WasmtimeVal>(nargs);
    for (var i = 0; i < nargs; i++) {
      args[i].toNative(argsPtr + i);
    }

    final funcTypePtr = wasmtime_func_type(store.context, ptr);
    final resultsTypePtr = wasm_functype_results(
      funcTypePtr,
    ).cast<WasmValTypeVec>();
    final nresults = resultsTypePtr.ref.size;
    final resultsPtr = calloc<WasmtimeVal>(nresults);
    final trapPtr = calloc<ffi.Pointer<wasm_trap_t>>();

    try {
      final error = wasmtime_func_call(
        store.context,
        ptr,
        argsPtr.cast(),
        nargs,
        resultsPtr.cast(),
        nresults,
        trapPtr,
      );

      if (error != ffi.nullptr) {
        // TODO: Handle error properly (extract message)
        throw Exception('Failed to call function');
      }

      if (trapPtr.value != ffi.nullptr) {
        final trap = Trap.fromPtr(trapPtr.value);
        throw Exception('Trap: ${trap.message}');
      }

      final results = <Val>[];
      for (var i = 0; i < nresults; i++) {
        results.add(Val.fromNative((resultsPtr + i).ref));
      }
      return results;
    } finally {
      calloc.free(argsPtr);
      calloc.free(resultsPtr);
      calloc.free(trapPtr);
      wasm_functype_delete(funcTypePtr);
    }
  }
}
