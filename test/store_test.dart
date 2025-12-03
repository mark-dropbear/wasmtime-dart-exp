import 'package:test/test.dart';
import 'package:wasmtime/wasmtime.dart';

void main() {
  group('Store', () {
    late Engine engine;

    setUp(() {
      engine = Engine();
    });

    tearDown(() {
      engine.dispose();
    });

    test('can be created and disposed', () {
      final store = Store(engine);
      store.dispose();
    });

    test('can be garbage collected', () {
      final store = Store(engine);
      store.gc();
      store.dispose();
    });
  });
}
