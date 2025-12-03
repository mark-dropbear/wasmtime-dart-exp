import 'dart:convert';
import 'dart:ffi' as ffi;

import 'package:ffi/ffi.dart';
import 'package:wasmtime/src/caller.dart';
import 'package:wasmtime/src/context.dart';
import 'package:wasmtime/src/store.dart';
import 'package:wasmtime/src/third_party/wasmtime.g.dart';
import 'package:wasmtime/src/trap.dart';
import 'package:wasmtime/src/types.dart';
import 'package:wasmtime/src/val.dart';

// Registry for host function callbacks
final _hostFunctionRegistry = <int, _HostFunctionInfo>{};
int _nextHostFunctionId = 1;

// Trampoline for host functions
ffi.Pointer<wasm_trap_t> _hostFunctionTrampoline(
  ffi.Pointer<ffi.Void> env,
  ffi.Pointer<wasmtime_caller> callerPtr,
  ffi.Pointer<wasmtime_val> argsPtr,
  int nargs,
  ffi.Pointer<wasmtime_val> resultsPtr,
  int nresults,
) {
  final id = env.address;
  final info = _hostFunctionRegistry[id];

  if (info == null) {
    // This should not happen if finalizers work correctly
    return ffi.nullptr; // TODO: Report error
  }

  final callback = info.callback;

  try {
    final caller = Caller.fromPtr(callerPtr);
    final args = <Val>[];
    final argsStructPtr = argsPtr.cast<WasmtimeVal>();
    for (var i = 0; i < nargs; i++) {
      args.add(Val.fromNativeWithContext(caller, (argsStructPtr + i).ref));
    }

    // Determine arguments to pass to Dart callback
    final dartArgs = <Object?>[];
    if (info.accessCaller) {
      dartArgs.add(caller);
    }
    dartArgs.addAll(args.map((v) => v.value));

    final result = Function.apply(callback, dartArgs);

    // Convert result back to WasmtimeVal
    final resultsStructPtr = resultsPtr.cast<WasmtimeVal>();
    if (nresults == 0) {
      // Void return
    } else if (nresults == 1) {
      // Use the expected result type from FuncType
      final resultType = info.type.results[0];
      final val = _dartToVal(result, resultType.kind);
      val.toNative(resultsStructPtr, context: caller);
    } else {
      // Multiple returns (List)
      final list = result as List;
      if (list.length != nresults) {
        throw Exception('Expected $nresults results, got ${list.length}');
      }
      for (var i = 0; i < nresults; i++) {
        final resultType = info.type.results[i];
        final val = _dartToVal(list[i], resultType.kind);
        val.toNative(resultsStructPtr + i, context: caller);
      }
    }

    return ffi.nullptr; // Success
  } on Object catch (e) {
    // Create a trap from the exception message
    final message = e.toString();
    final messageBytes = utf8.encode(message);
    // Allocate length + 1 for null terminator
    final messagePtr = calloc<ffi.Uint8>(messageBytes.length + 1);
    final messageList = messagePtr.asTypedList(messageBytes.length + 1);
    messageList.setAll(0, messageBytes);
    messageList[messageBytes.length] = 0; // Null terminator

    final messageVec = calloc<wasm_byte_vec_t>();
    // Pass length including null terminator? Or excluding?
    // "stringz expected" suggests it wants a C string.
    // If we pass the vector, Wasmtime probably checks if the last byte is 0.
    // So we should include it in the vector size.
    wasm_byte_vec_new(messageVec, messageBytes.length + 1, messagePtr.cast());

    final trap = wasm_trap_new(info.store.ptr.cast(), messageVec);

    calloc.free(messagePtr);
    wasm_byte_vec_delete(messageVec);
    calloc.free(messageVec);

    return trap;
  }
}

Val _dartToVal(Object? obj, ValKind kind) {
  switch (kind) {
    case ValKind.i32:
      return Val.i32(obj as int);
    case ValKind.i64:
      return Val.i64(obj as int);
    case ValKind.f32:
      return Val.f32(obj as double);
    case ValKind.f64:
      return Val.f64(obj as double);
    case ValKind.v128:
      return Val.v128(obj as V128);
    case ValKind.funcref:
      return Val.funcref(obj as Func?);
    case ValKind.externref:
      return Val.externref(obj);
    default:
      throw ArgumentError('Unsupported ValKind: $kind');
  }
}

/// Represents a WebAssembly function.
class Func {
  /// The native pointer to the function.
  final ffi.Pointer<wasmtime_func> ptr;

  Func._(this.ptr);

  @override
  // Func is a wrapper around a pointer, so it's effectively immutable.
  // ignore: avoid_equals_and_hash_code_on_mutable_classes
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! Func) return false;
    // Compare the content of the struct
    final thisStruct = ptr.cast<WasmtimeFuncStruct>().ref;
    final otherStruct = other.ptr.cast<WasmtimeFuncStruct>().ref;
    return thisStruct.store_id == otherStruct.store_id &&
        thisStruct.private_data ==
            otherStruct.private_data; // index is in private_data?
    // Wait, WasmtimeFuncStruct definition:
    // external int store_id;
    // external ffi.Pointer<ffi.Void> private_data;
    // Yes.
  }

  @override
  // Func is a wrapper around a pointer, so it's effectively immutable.
  // ignore: avoid_equals_and_hash_code_on_mutable_classes
  int get hashCode {
    final struct = ptr.cast<WasmtimeFuncStruct>().ref;
    return Object.hash(struct.store_id, struct.private_data);
  }

  /// Creates a [Func] from a native [WasmtimeFuncStruct].
  factory Func.fromNative(WasmtimeFuncStruct native) {
    final ptr = calloc<wasmtime_func>();
    final customPtr = ptr.cast<WasmtimeFuncStruct>();
    customPtr.ref.store_id = native.store_id;
    customPtr.ref.private_data = native.private_data;
    return Func._(ptr);
  }

  /// Creates a new host function from a Dart callback.
  factory Func.from(
    Store store,
    FuncType type,
    Function callback, {
    bool accessCaller = false,
  }) {
    final id = _nextHostFunctionId++;
    _hostFunctionRegistry[id] = _HostFunctionInfo(
      callback,
      store,
      type,
      accessCaller: accessCaller,
    );

    final finalizer =
        ffi.NativeCallable<ffi.Void Function(ffi.Pointer<ffi.Void>)>.listener(
          _hostFunctionFinalizer,
        );

    final funcPtr = calloc<wasmtime_func>();

    wasmtime_func_new(
      store.context,
      type.ptr,
      ffi.NativeCallable<
            ffi.Pointer<wasm_trap_t> Function(
              ffi.Pointer<ffi.Void>,
              ffi.Pointer<wasmtime_caller>,
              ffi.Pointer<wasmtime_val>,
              ffi.Size,
              ffi.Pointer<wasmtime_val>,
              ffi.Size,
            )
          >.isolateLocal(_hostFunctionTrampoline)
          .nativeFunction,
      ffi.Pointer.fromAddress(id),
      finalizer.nativeFunction,
      funcPtr,
    );

    return Func._(funcPtr);
  }

  /// Disposes of the [Func].
  void dispose() {
    calloc.free(ptr);
  }

  /// Calls the function with the given arguments.
  List<Val> call(WasmContext context, {List<Val> args = const []}) {
    final nargs = args.length;
    final argsPtr = calloc<WasmtimeVal>(nargs);
    for (var i = 0; i < nargs; i++) {
      args[i].toNative(argsPtr + i, context: context);
    }

    final funcTypePtr = wasmtime_func_type(context.context, ptr);
    final resultsTypePtr = wasm_functype_results(
      funcTypePtr,
    ).cast<WasmValTypeVec>();
    final nresults = resultsTypePtr.ref.size;
    final resultsPtr = calloc<WasmtimeVal>(nresults);
    final trapPtr = calloc<ffi.Pointer<wasm_trap_t>>();

    try {
      final error = wasmtime_func_call(
        context.context,
        ptr,
        argsPtr.cast(),
        nargs,
        resultsPtr.cast(),
        nresults,
        trapPtr,
      );

      if (error != ffi.nullptr) {
        final messageVec = calloc<wasm_byte_vec_t>();
        wasmtime_error_message(error, messageVec);
        final message = utf8.decode(
          messageVec.ref.data.cast<ffi.Uint8>().asTypedList(
            messageVec.ref.size,
          ),
        );
        wasm_byte_vec_delete(messageVec);
        calloc.free(messageVec);
        wasmtime_error_delete(error);
        throw Exception('Failed to call function: $message');
      }

      if (trapPtr.value != ffi.nullptr) {
        final trap = Trap.fromPtr(trapPtr.value);
        throw Exception('Trap: ${trap.message}');
      }

      final results = <Val>[];
      for (var i = 0; i < nresults; i++) {
        results.add(Val.fromNativeWithContext(context, (resultsPtr + i).ref));
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

class _HostFunctionInfo {
  final Function callback;
  final Store store;
  final FuncType type;
  final bool accessCaller;

  _HostFunctionInfo(
    this.callback,
    this.store,
    this.type, {
    required this.accessCaller,
  });
}

void _hostFunctionFinalizer(ffi.Pointer<ffi.Void> env) {
  final id = env.address;
  _hostFunctionRegistry.remove(id);
}
