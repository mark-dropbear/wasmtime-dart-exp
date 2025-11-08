import 'package:wasmtime/wasmtime.dart';
import 'package:test/test.dart';

void main() {
  group('Wasmtime', () {
    test('can create and delete an engine', () {
      final engine = wasm_engine_new();
      expect(engine.address, isNot(0));
      wasm_engine_delete(engine);
      // The pointer itself is not null after delete, but the underlying resource is freed.
      // There is no good way to test this without trying to use the engine, which would crash.
    });

    test('can convert WAT to WASM', () {
      final wasmtime = Wasmtime();
      final wat =
          '(module (func (export "add") (param i32 i32) (result i32) (i32.add)))';
      final result = wasmtime.wasmtimeWat2Wasm(wat);
      expect(result.wasmBytes, isNotEmpty);
    });

    test('throws WasmtimeException for invalid WAT', () {
      final wasmtime = Wasmtime();
      final invalidWat =
          '(module (func (export "add") (param i32 i32) (result i32) (i32.add))))'; // Extra parenthesis
      expect(
        () => wasmtime.wasmtimeWat2Wasm(invalidWat),
        throwsA(isA<WasmtimeException>()),
      );
    });
  });
}
