import 'dart:ffi' as ffi;
import 'package:ffi/ffi.dart';
import 'package:wasmtime/src/third_party/wasmtime.g.dart';

enum TrapCode {
  stackOverflow,
  memoryOutOfBounds,
  heapMisaligned,
  tableOutOfBounds,
  indirectCallToNull,
  badSignature,
  integerOverflow,
  integerDivisionByZero,
  badConversionToInteger,
  unreachableCode,
  interrupt,
  alwaysTrapAdapter,
  outOfFuel,
  unknown;

  static TrapCode fromValue(int value) {
    // These values must match wasmtime_trap_code_enum in wasmtime.h
    // The C enum is 0-indexed.
    if (value >= 0 && value < TrapCode.values.length) {
      return TrapCode.values[value];
    }
    return TrapCode.unknown;
  }
}

class Frame {
  final int funcIndex;
  final int funcOffset;
  final int moduleOffset;
  final String? funcName;
  final String? moduleName;

  Frame._({
    required this.funcIndex,
    required this.funcOffset,
    required this.moduleOffset,
    this.funcName,
    this.moduleName,
  });

  @override
  String toString() {
    return 'Frame(funcIndex: $funcIndex, funcOffset: $funcOffset, moduleOffset: $moduleOffset, funcName: $funcName, moduleName: $moduleName)';
  }
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
      if (byteVec.ref.data == ffi.nullptr) return '';
      final str = byteVec.ref.data.cast<ffi.Uint8>().asTypedList(
        byteVec.ref.size,
      );
      return String.fromCharCodes(str);
    } finally {
      wasm_byte_vec_delete(byteVec);
      calloc.free(byteVec);
    }
  }

  TrapCode? get code {
    final codePtr = calloc<ffi.Uint8>();
    try {
      if (wasmtime_trap_code(_ptr, codePtr)) {
        return TrapCode.fromValue(codePtr.value);
      }
      return null;
    } finally {
      calloc.free(codePtr);
    }
  }

  List<Frame> get frames {
    final vec = calloc<wasm_frame_vec_t>();
    try {
      wasm_trap_trace(_ptr, vec);
      final list = <Frame>[];
      final data = vec.ref.data;
      for (var i = 0; i < vec.ref.size; i++) {
        final framePtr = data[i];

        String? funcName;
        final funcNameVec = wasmtime_frame_func_name(framePtr);
        if (funcNameVec != ffi.nullptr) {
          funcName = String.fromCharCodes(
            funcNameVec.ref.data.cast<ffi.Uint8>().asTypedList(
              funcNameVec.ref.size,
            ),
          );
        }

        String? moduleName;
        final moduleNameVec = wasmtime_frame_module_name(framePtr);
        if (moduleNameVec != ffi.nullptr) {
          moduleName = String.fromCharCodes(
            moduleNameVec.ref.data.cast<ffi.Uint8>().asTypedList(
              moduleNameVec.ref.size,
            ),
          );
        }

        list.add(
          Frame._(
            funcIndex: wasm_frame_func_index(framePtr),
            funcOffset: wasm_frame_func_offset(framePtr),
            moduleOffset: wasm_frame_module_offset(framePtr),
            funcName: funcName,
            moduleName: moduleName,
          ),
        );
      }
      return list;
    } finally {
      wasm_frame_vec_delete(vec);
      calloc.free(vec);
    }
  }

  void dispose() {
    wasm_trap_delete(_ptr);
  }
}
