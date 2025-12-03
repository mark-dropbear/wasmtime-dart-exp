import 'package:test/test.dart';
import 'package:wasmtime/wasmtime.dart';

void main() {
  late Engine engine;
  late Store store;
  late Linker linker;

  setUp(() {
    engine = Engine();
    store = Store(engine);
    linker = Linker(engine);
  });

  tearDown(() {
    linker.dispose();
    store.dispose();
    engine.dispose();
  });

  test('can be created and disposed', () {
    // Setup and teardown handle this
  });

  test('can define and instantiate module', () {
    const wat = '''
      (module
        (func (export "run") (result i32)
          i32.const 42
        )
      )
    ''';
    final module = Module.fromText(engine, wat);
    linker.defineModule(store, 'test', module);

    // Instantiate empty module to test linker
    const emptyWat = '(module)';
    final emptyModule = Module.fromText(engine, emptyWat);
    final instance = linker.instantiate(store, emptyModule);

    // Clean up
    instance.dispose();
    module.dispose();
    emptyModule.dispose();
  });
}
