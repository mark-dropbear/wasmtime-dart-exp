import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:wasmtime/wasmtime.dart';

void main() {
  group('Module', () {
    late Engine engine;

    setUp(() {
      engine = Engine();
    });

    tearDown(() {
      engine.dispose();
    });

    test('can be created from text', () {
      const wat = r'''
        (module
          (func (export "run"))
        )
      ''';
      final module = Module.fromText(engine, wat);
      module.dispose();
    });

    test('can be created from binary', () {
      // Minimal valid Wasm module binary
      final bytes = Uint8List.fromList([
        0x00, 0x61, 0x73, 0x6d, // Magic
        0x01, 0x00, 0x00, 0x00, // Version
      ]);
      final module = Module.fromBinary(engine, bytes);
      module.dispose();
    });

    test('validates valid module', () {
      final bytes = Uint8List.fromList([
        0x00, 0x61, 0x73, 0x6d, // Magic
        0x01, 0x00, 0x00, 0x00, // Version
      ]);
      Module.validate(engine, bytes);
    });

    test('fails to validate invalid module', () {
      final bytes = Uint8List.fromList([
        0x00, 0x00, 0x00, 0x00, // Invalid Magic
      ]);
      expect(() => Module.validate(engine, bytes), throwsException);
    });

    test('fails to create from invalid text', () {
      const wat = 'invalid wat';
      expect(() => Module.fromText(engine, wat), throwsException);
    });
  });
}
