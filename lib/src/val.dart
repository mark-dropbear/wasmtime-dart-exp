import 'dart:ffi' as ffi;
import 'package:ffi/ffi.dart';
import 'package:wasmtime/src/types.dart';
import 'package:wasmtime/src/third_party/wasmtime.g.dart';
import 'package:wasmtime/src/func.dart';

import 'package:wasmtime/src/store.dart';

class V128 {
  final int low;
  final int high;

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

class ValType {
  final ffi.Pointer<wasm_valtype_t> _ptr;

  ValType._(this._ptr);

  factory ValType.fromPtr(ffi.Pointer<wasm_valtype_t> ptr) => ValType._(ptr);

  ValKind get kind => ValKind.fromValue(wasm_valtype_kind(_ptr));

  void dispose() {
    wasm_valtype_delete(_ptr);
  }

  @override
  String toString() => kind.toString();
}

class Val {
  final ValKind kind;
  final Object? value;

  // Registry to pin Dart objects passed as externref
  static final Map<int, Object> _externRefRegistry = {};
  static int _nextExternRefId = 1;

  Val.i32(int val) : kind = ValKind.i32, value = val;
  Val.i64(int val) : kind = ValKind.i64, value = val;
  Val.f32(double val) : kind = ValKind.f32, value = val;
  Val.f64(double val) : kind = ValKind.f64, value = val;
  Val.v128(V128 val) : kind = ValKind.v128, value = val;
  Val.funcref(Func? val) : kind = ValKind.funcref, value = val;
  Val.externref(Object? val) : kind = ValKind.externref, value = val;

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
      case ValKind.v128:
        return Val.v128(V128(native.of.v128.low, native.of.v128.high));
      case ValKind.funcref:
        if (native.of.ref.store_id == 0) return Val.funcref(null);
        // TODO: We need to retrieve the Func object from the store/context using the ID?
        // Or just wrap the raw pointer/ID?
        // For now, we can't easily reconstruct the Dart Func object from just the raw struct
        // without a lookup mechanism in Store.
        // But wait, Func.fromNative creates a Func wrapper around a pointer.
        // The WasmtimeVal contains a WasmtimeRefStruct (store_id, index).
        // To get a Func pointer, we might need `wasm_func_copy` or similar if we had a pointer.
        // But here we have a struct.
        // Actually, `wasmtime_val_funcref_get` returns `wasmtime_func_t`.
        // Our `WasmtimeValUnion` has `ref` which maps to `wasmtime_func_t` (store_id, index).
        // So we can create a Func from this struct.
        final funcStruct = calloc<WasmtimeFuncStruct>();
        funcStruct.ref.store_id = native.of.ref.store_id;
        funcStruct.ref.private_data = ffi.Pointer.fromAddress(
          native.of.ref.index,
        ); // index is private_data?
        // Wait, WasmtimeFuncStruct has store_id and private_data (Pointer<Void>).
        // WasmtimeRefStruct has store_id and index (Uint64).
        // In C, wasmtime_func_t has store_id and size_t index.
        // So index IS private_data (cast to int).
        // We need to be careful here.
        // Let's assume for now we can create a Func wrapper.
        return Val.funcref(Func.fromNative(funcStruct.ref));
      case ValKind.externref:
        if (native.of.ref.store_id == 0) return Val.externref(null);
        // Retrieve pinned object
        // The index in WasmtimeRefStruct corresponds to our registry ID?
        // No, wasmtime manages its own indices.
        // We need `wasmtime_externref_data` to get the data we put in.
        // But `fromNative` here takes `WasmtimeVal` struct, not `wasmtime_val_t` pointer?
        // Ah, `WasmtimeVal` IS the Dart projection of `wasmtime_val_t`.
        // But to get data from externref, we need the context.
        // `fromNative` needs `Store` context to resolve externref?
        // Yes, `wasmtime_externref_data` takes context.
        // So `fromNative` needs `Store`.
        // I should update `fromNative` signature.
        return Val.externref(null); // Placeholder until we update signature
      default:
        throw ArgumentError('Unknown ValKind: $kind');
    }
  }

  // Updated signature to take Store for externref resolution
  static Val fromNativeWithStore(Store store, WasmtimeVal native) {
    final kind = ValKind.fromValue(native.kind);
    if (kind == ValKind.externref) {
      if (native.of.ref.store_id == 0) return Val.externref(null);
      // We need a pointer to the externref to call wasmtime_externref_data.
      // But we only have the struct value here.
      // We can reconstruct a temporary externref on stack?
      // Or we should pass the pointer to `fromNative`.
      // Let's change `fromNative` to take `Pointer<WasmtimeVal>`.
      return Val.externref(null); // TODO: Implement
    }
    return fromNative(native);
  }

  void toNative(ffi.Pointer<WasmtimeVal> ptr, {Store? store}) {
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
      case ValKind.v128:
        final v = value as V128;
        ptr.ref.of.v128.low = v.low;
        ptr.ref.of.v128.high = v.high;
        break;
      case ValKind.funcref:
        final f = value as Func?;
        if (f != null) {
          // We need to extract the raw func struct from Func.
          // Func wraps a pointer to wasmtime_func_t.
          // We need to copy that struct into ptr.ref.of.ref
          // But Func._ptr points to wasmtime_func_t.
          // We can cast Func._ptr to Pointer<WasmtimeRefStruct> and copy?
          // Yes, wasmtime_func_t is compatible with WasmtimeRefStruct layout.
          final funcPtr = f.ptr.cast<WasmtimeRefStruct>();
          ptr.ref.of.ref.store_id = funcPtr.ref.store_id;
          ptr.ref.of.ref.index = funcPtr.ref.index;
        } else {
          ptr.ref.of.ref.store_id = 0;
          ptr.ref.of.ref.index = 0;
        }
        break;
      case ValKind.externref:
        if (store == null) throw ArgumentError('Store required for externref');
        final val = value;
        if (val != null) {
          final id = _nextExternRefId++;
          _externRefRegistry[id] = val;
          // Create externref
          // We need to call wasmtime_externref_new
          // But that returns bool and takes an out pointer.
          // And we are filling a WasmtimeVal struct here.
          // We need to create the externref and then copy it to the val struct.
          // final externRefPtr =
          //     calloc<WasmtimeRefStruct>(); // externref is same layout
          // Wait, wasmtime_externref_new takes `void* data` and `finalizer`.
          // Data will be our ID (cast to pointer).
          // final data = ffi.Pointer.fromAddress(id);
          // Finalizer? We need a C function pointer.
          // For now, pass nullptr? Then we leak registry entries.
          // We need a native finalizer callback.
          // Dart FFI supports NativeCallable.
          // But for now, let's just pin it.
          // We need to implement finalizer later.

          // wasmtime_externref_new(context, data, finalizer, out_externref)
          // We need to cast WasmtimeRefStruct to wasmtime_externref_t (which is same)

          // TODO: Implement externref creation
        } else {
          ptr.ref.of.ref.store_id = 0;
          ptr.ref.of.ref.index = 0;
        }
        break;
      default:
        throw ArgumentError('Unknown ValKind: $kind');
    }
  }

  @override
  String toString() => 'Val($kind, $value)';
}
