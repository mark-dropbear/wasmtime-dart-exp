import 'package:wasmtime/wasmtime.dart';
import 'package:test/test.dart';

void main() {
  group('Engine', () {
    test('can be created and disposed', () {
      final engine = Engine();
      expect(engine, isNotNull);
      engine.dispose();
      // Expect no errors on double dispose
      engine.dispose();
    });

    test('can be created with config and disposed', () {
      final config = Config();
      final engine = Engine.withConfig(config);
      expect(engine, isNotNull);
      engine.dispose();
      // Expect no errors on double dispose
      engine.dispose();
    });

    test('incrementEpoch works', () {
      final engine = Engine();
      engine.incrementEpoch();
      engine.dispose();
    });

    test('isPulley works', () {
      final engine = Engine();
      // We can't assert a specific value, just that it doesn't crash
      expect(engine.isPulley, isA<bool>());
      engine.dispose();
    });
  });
}
