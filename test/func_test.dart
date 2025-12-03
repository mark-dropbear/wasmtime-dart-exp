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

  test('can call function', () {
    const wat = '''
      (module
        (func (export "add") (param i32 i32) (result i32)
          local.get 0
          local.get 1
          i32.add
        )
      )
    ''';
    final module = Module.fromText(engine, wat);
    final instance = linker.instantiate(store, module);
    final extern = instance.getExport(store, 'add');
    final add = extern?.asFunc;

    expect(add, isNotNull);

    final results = add!.call(store, [Val.i32(1), Val.i32(2)]);
    expect(results, hasLength(1));
    expect(results[0].kind, ValKind.i32);
    expect(results[0].value, 3);

    add.dispose();
    extern?.dispose();
    instance.dispose();
    module.dispose();
  });

  test('handles traps', () {
    const wat = '''
      (module
        (func (export "trap")
          unreachable
        )
      )
    ''';
    final module = Module.fromText(engine, wat);
    final instance = linker.instantiate(store, module);
    final extern = instance.getExport(store, 'trap');
    final trapFunc = extern?.asFunc;

    expect(trapFunc, isNotNull);

    expect(() => trapFunc!.call(store, []), throwsException);

    trapFunc?.dispose();
    extern?.dispose();
    instance.dispose();
    module.dispose();
  });
}
