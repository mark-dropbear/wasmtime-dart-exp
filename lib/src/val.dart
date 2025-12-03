import 'dart:ffi' as ffi;

import 'package:ffi/ffi.dart';
import 'package:meta/meta.dart';
import 'package:wasmtime/src/context.dart';
import 'package:wasmtime/src/func.dart';
import 'package:wasmtime/src/third_party/wasmtime.g.dart';
import 'package:wasmtime/src/types.dart';

/// A 128-bit vector value.
@immutable
class V128 {
  /// The low 64 bits of the vector.
  final int low;

  /// The high 64 bits of the vector.
  final int high;

  /// Creates a new [V128] value.
  const V128(this.low, this.high);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is V128 &&
          runtimeType == other.runtimeType &&
          low == other.low &&
          high == other.high;

  @override
  int get hashCode => low.hashCode ^ high.hashCode;

  @override
  String toString() =>
      'V128(0x${low.toRadixString(16)}, 0x${high.toRadixString(16)})';
}

/// Represents the type of a WebAssembly value.
class ValType {
  final ffi.Pointer<wasm_valtype_t> _ptr;

  ValType._(this._ptr);

  /// Creates a [ValType] from a raw pointer.
  factory ValType.fromPtr(ffi.Pointer<wasm_valtype_t> ptr) => ValType._(ptr);

  /// Returns the [ValKind] of this type.
  ValKind get kind => ValKind.fromValue(wasm_valtype_kind(_ptr));

  /// Disposes of the [ValType].
  void dispose() {
    wasm_valtype_delete(_ptr);
  }

  @override
  String toString() => kind.toString();
}

/// Represents the type of a WebAssembly function.
class FuncType {
  final ffi.Pointer<wasm_functype_t> _ptr;

  FuncType._(this._ptr);

  /// Creates a new [FuncType] with the given parameters and results.
  factory FuncType(List<ValKind> params, List<ValKind> results) {
    final paramsVec = calloc<WasmValTypeVec>();
    final resultsVec = calloc<WasmValTypeVec>();

    try {
      paramsVec.ref.size = params.length;
      paramsVec.ref.data = calloc<ffi.Pointer<wasm_valtype_t>>(params.length);
      for (var i = 0; i < params.length; i++) {
        paramsVec.ref.data[i] = wasm_valtype_new(params[i].toWasmKind());
      }

      resultsVec.ref.size = results.length;
      resultsVec.ref.data = calloc<ffi.Pointer<wasm_valtype_t>>(results.length);
      for (var i = 0; i < results.length; i++) {
        resultsVec.ref.data[i] = wasm_valtype_new(results[i].toWasmKind());
      }

      // wasm_functype_new takes ownership of the vectors' contents (the valtypes),
      // but does it take ownership of the vector structs themselves?
      // The C API `wasm_functype_new` takes `wasm_valtype_vec_t*`.
      // Usually it copies the vector content.
      // Wait, `wasm_functype_new` signature in C is `wasm_functype_t* wasm_functype_new(wasm_valtype_vec_t* params, wasm_valtype_vec_t* results)`.
      // It usually TAKES OWNERSHIP of the vectors passed in.
      // This means we should NOT free the vectors' data if `wasm_functype_new` succeeds.
      // But we allocated the `WasmValTypeVec` struct itself on heap.
      // The C API expects `wasm_valtype_vec_t*`.
      // If we pass a pointer to our struct, Wasmtime will read from it.
      // Does it free the pointer we passed?
      // Standard Wasm C API `wasm_functype_new` takes ownership of the vectors.
      // This means it will call `wasm_valtype_vec_delete` on them?
      // No, it takes `wasm_valtype_vec_t*`.
      // If it takes ownership, it means it consumes the data.
      // We should verify this.
      // Assuming it takes ownership of the CONTENTS.
      // We should probably use `wasm_valtype_vec_new` if available, but it's not.
      // So we manually built it.
      // If `wasm_functype_new` takes ownership, it will eventually free the `wasm_valtype_t`s.
      // We just need to free our `WasmValTypeVec` struct wrapper if Wasmtime copies the vector struct content.
      // Usually C structs are passed by value if they are small, but here they are pointers.
      // `wasm_functype_new` takes pointers.
      // It likely copies the vector description (size, data ptr) and takes ownership of the data ptr.
      // So we should free `paramsVec` and `resultsVec` structs, but NOT `paramsVec.ref.data` (the array of pointers) or the `wasm_valtype_t`s.

      final ptr = wasm_functype_new(paramsVec.cast(), resultsVec.cast());

      return FuncType._(ptr);
    } finally {
      // We free the struct wrappers.
      // We do NOT free the data arrays or the valtypes, as ownership is transferred.
      calloc.free(paramsVec);
      calloc.free(resultsVec);
    }
  }

  /// Creates a [FuncType] from a raw pointer.
  factory FuncType.fromPtr(ffi.Pointer<wasm_functype_t> ptr) => FuncType._(ptr);

  /// Returns the parameter types of this function type.
  List<ValType> get params {
    final vec = wasm_functype_params(_ptr);
    final list = <ValType>[];
    // vec is a pointer to wasm_valtype_vec_t.
    // We need to read it.
    final struct = vec.cast<WasmValTypeVec>().ref;
    for (var i = 0; i < struct.size; i++) {
      // We need to clone the type because the vector owns it?
      // Or does ValType wrap a reference?
      // ValType.fromPtr wraps the pointer.
      // If we return ValType, user might call dispose().
      // But these types belong to the FuncType.
      // We should probably return a copy or a non-owning wrapper.
      // But ValType.dispose calls wasm_valtype_delete.
      // So we must return a COPY.
      final typePtr = struct.data[i];
      final copy = wasm_valtype_new(wasm_valtype_kind(typePtr));
      list.add(ValType.fromPtr(copy));
    }
    return list;
  }

  /// Returns the result types of this function type.
  List<ValType> get results {
    final vec = wasm_functype_results(_ptr);
    final list = <ValType>[];
    final struct = vec.cast<WasmValTypeVec>().ref;
    for (var i = 0; i < struct.size; i++) {
      final typePtr = struct.data[i];
      final copy = wasm_valtype_new(wasm_valtype_kind(typePtr));
      list.add(ValType.fromPtr(copy));
    }
    return list;
  }

  /// Returns the native pointer to the function type.
  ffi.Pointer<wasm_functype_t> get ptr => _ptr;

  /// Disposes of the [FuncType].
  void dispose() {
    wasm_functype_delete(_ptr);
  }
}

/// Represents a WebAssembly value.
class Val {
  /// The kind of the value.
  final ValKind kind;

  /// The underlying value.
  final Object? value;

  // Registry to pin Dart objects passed as externref
  static final Map<int, Object> _externRefRegistry = {};
  static int _nextExternRefId = 1;

  static void _finalizer(ffi.Pointer<ffi.Void> data) {
    final id = data.address;
    _externRefRegistry.remove(id);
  }

  static final _finalizerNative =
      ffi.NativeCallable<ffi.Void Function(ffi.Pointer<ffi.Void>)>.listener(
        _finalizer,
      );

  /// Creates an i32 value.
  Val.i32(int val) : kind = ValKind.i32, value = val;

  /// Creates an i64 value.
  Val.i64(int val) : kind = ValKind.i64, value = val;

  /// Creates an f32 value.
  Val.f32(double val) : kind = ValKind.f32, value = val;

  /// Creates an f64 value.
  Val.f64(double val) : kind = ValKind.f64, value = val;

  /// Creates a v128 value.
  Val.v128(V128 val) : kind = ValKind.v128, value = val;

  /// Creates a funcref value.
  Val.funcref(Func? val) : kind = ValKind.funcref, value = val;

  /// Creates an externref value.
  Val.externref(Object? val) : kind = ValKind.externref, value = val;

  /// Creates a [Val] from a native [WasmtimeVal] struct.
  factory Val.fromNative(WasmtimeVal native) {
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
      case ValKind.v128:
        return Val.v128(V128(native.of.v128.low, native.of.v128.high));
      case ValKind.funcref:
        if (native.of.funcref.store_id == 0) return Val.funcref(null);
        return Val.funcref(Func.fromNative(native.of.funcref));
      case ValKind.externref:
        if (native.of.externref.store_id == 0) return Val.externref(null);
        // Without context, we can't retrieve the data.
        return Val.externref(null);
      default:
        throw ArgumentError('Unknown ValKind: $kind');
    }
  }

  /// Creates a [Val] from a native [WasmtimeVal] struct, using the provided [WasmContext] for context.
  factory Val.fromNativeWithContext(WasmContext context, WasmtimeVal native) {
    final kind = ValKind.fromValue(native.kind);
    if (kind == ValKind.externref) {
      if (native.of.externref.store_id == 0) return Val.externref(null);

      final externRefPtr = calloc<WasmtimeExternRefStruct>();
      externRefPtr.ref.store_id = native.of.externref.store_id;
      externRefPtr.ref.private1 = native.of.externref.private1;
      externRefPtr.ref.private2 = native.of.externref.private2;
      externRefPtr.ref.private3 = native.of.externref.private3;

      final dataPtr = wasmtime_externref_data(
        context.context,
        externRefPtr.cast(),
      );
      calloc.free(externRefPtr);

      if (dataPtr == ffi.nullptr) return Val.externref(null);

      final id = dataPtr.address;
      final obj = _externRefRegistry[id];
      return Val.externref(obj);
    }
    return Val.fromNative(native);
  }

  /// Converts this value to a native [WasmtimeVal] struct.
  void toNative(ffi.Pointer<WasmtimeVal> ptr, {WasmContext? context}) {
    ptr.ref.kind = kind.value;
    switch (kind) {
      case ValKind.i32:
        ptr.ref.of.i32 = value as int;
      case ValKind.i64:
        ptr.ref.of.i64 = value as int;
      case ValKind.f32:
        ptr.ref.of.f32 = value as double;
      case ValKind.f64:
        ptr.ref.of.f64 = value as double;
      case ValKind.v128:
        final v = value as V128;
        ptr.ref.of.v128.low = v.low;
        ptr.ref.of.v128.high = v.high;
      case ValKind.funcref:
        final f = value as Func?;
        if (f != null) {
          final funcPtr = f.ptr.cast<WasmtimeFuncStruct>();
          ptr.ref.of.funcref.store_id = funcPtr.ref.store_id;
          ptr.ref.of.funcref.private_data = funcPtr.ref.private_data;
        } else {
          ptr.ref.of.funcref.store_id = 0;
          ptr.ref.of.funcref.private_data = ffi.nullptr;
        }
      case ValKind.externref:
        if (context == null) {
          throw ArgumentError('WasmContext required for externref');
        }
        final val = value;
        if (val != null) {
          final id = _nextExternRefId++;
          _externRefRegistry[id] = val;
          final data = ffi.Pointer.fromAddress(id);

          final outExternRef = calloc<WasmtimeExternRefStruct>();
          final success = wasmtime_externref_new(
            context.context,
            data.cast(),
            _finalizerNative.nativeFunction,
            outExternRef.cast(),
          );

          if (!success) {
            calloc.free(outExternRef);
            throw Exception('Failed to create externref');
          }

          ptr.ref.kind = ValKind.externref.value;
          ptr.ref.of.externref = outExternRef.ref;
          calloc.free(outExternRef);
        } else {
          ptr.ref.of.externref.store_id = 0;
          ptr.ref.of.externref.private1 = 0;
          ptr.ref.of.externref.private2 = 0;
          ptr.ref.of.externref.private3 = ffi.nullptr;
        }
      default:
        throw ArgumentError('Unknown ValKind: $kind');
    }
  }

  @override
  String toString() => 'Val($kind, $value)';
}
