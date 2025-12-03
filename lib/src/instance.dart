import 'dart:ffi' as ffi;
import 'package:ffi/ffi.dart';
import 'package:wasmtime/src/store.dart';
import 'package:wasmtime/src/extern.dart';
import 'package:wasmtime/src/types.dart';
import 'package:wasmtime/src/third_party/wasmtime.g.dart';

class Instance {
  final ffi.Pointer<wasmtime_instance> _ptr;

  Instance.fromPtr(this._ptr);

  void dispose() {
    calloc.free(_ptr);
  }

  Extern? getExport(Store store, String name) {
    final namePtr = name.toNativeUtf8();
    final itemPtr = calloc<WasmtimeExtern>();

    var found = false;
    try {
      found = wasmtime_instance_export_get(
        store.context,
        _ptr,
        namePtr.cast(),
        name.length,
        itemPtr.cast(),
      );

      if (found) {
        return Extern.fromNative(itemPtr);
      }
      return null;
    } finally {
      calloc.free(namePtr);
      // We don't free itemPtr if we return it wrapped in Extern?
      // Extern takes ownership?
      // "APIs that return #wasmtime_extern_t require that #wasmtime_extern_delete is called"
      // But wasmtime_instance_export_get says:
      // "Doesn't take ownership of any arguments but does return ownership of the #wasmtime_extern_t."
      // So we own the content.
      // Extern class should manage this memory?
      // Currently Extern wraps a pointer.
      // If we return Extern, it should probably own the pointer.
      // But if we return null, we should free it.
      if (!found) {
        calloc.free(itemPtr);
      }
    }
  }
}
