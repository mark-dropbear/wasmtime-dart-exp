import 'dart:ffi' as ffi;
import 'package:ffi/ffi.dart';
import 'package:wasmtime/src/third_party/wasmtime.g.dart';

/// Represents the code of a trap.
enum TrapCode {
  /// Stack overflow.
  stackOverflow,

  /// Memory out of bounds.
  memoryOutOfBounds,

  /// Heap misaligned.
  heapMisaligned,

  /// Table out of bounds.
  tableOutOfBounds,

  /// Indirect call to null.
  indirectCallToNull,

  /// Bad signature.
  badSignature,

  /// Integer overflow.
  integerOverflow,

  /// Integer division by zero.
  integerDivisionByZero,

  /// Bad conversion to integer.
  badConversionToInteger,

  /// Unreachable code.
  unreachableCode,

  /// Interrupt.
  interrupt,

  /// Always trap adapter.
  alwaysTrapAdapter,

  /// Out of fuel.
  outOfFuel,

  /// Unknown trap code.
  unknown;

  /// Creates a [TrapCode] from a native value.
  static TrapCode fromValue(int value) {
    // These values must match wasmtime_trap_code_enum in wasmtime.h
    // The C enum is 0-indexed.
    if (value >= 0 && value < TrapCode.values.length) {
      return TrapCode.values[value];
    }
    return TrapCode.unknown;
  }
}

/// Represents a frame in a trap trace.
class Frame {
  /// The function index in the module.
  final int funcIndex;

  /// The offset of the instruction in the function.
  final int funcOffset;

  /// The offset of the instruction in the module.
  final int moduleOffset;

  /// The name of the function, if available.
  final String? funcName;

  /// The name of the module, if available.
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

/// Represents a WebAssembly trap.
class Trap {
  final ffi.Pointer<wasm_trap_t> _ptr;

  Trap._(this._ptr);

  /// Creates a [Trap] from a raw pointer.
  factory Trap.fromPtr(ffi.Pointer<wasm_trap_t> ptr) => Trap._(ptr);

  /// Returns the raw pointer to the trap.
  ffi.Pointer<wasm_trap_t> get ptr => _ptr;

  /// Returns the trap message.
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

  /// Returns the trap code, if any.
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

  /// Returns the frames in the trap trace.
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

  /// Disposes of the [Trap].
  void dispose() {
    wasm_trap_delete(_ptr);
  }
}
