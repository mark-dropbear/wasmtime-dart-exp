import 'package:wasmtime/wasmtime.dart';

void main() {
  final wasmtime = Wasmtime();

  final wat = '''(module
  (func \$hello (import "" "hello"))
  (func (export "run") (call \$hello))
)''';
  try {
    final result = wasmtime.wasmtimeWat2Wasm(wat);
    print(
      'WAT converted to WASM successfully. WASM bytes length: ${result.wasmBytes.length}',
    );
    print(result);
  } on WasmtimeException catch (e) {
    print('Error converting WAT to WASM: ${e.message}');
  }

  final engine = wasm_engine_new();
  print('Wasm engine created: $engine');
  wasm_engine_delete(engine);
  print('Wasm engine deleted.');
}
