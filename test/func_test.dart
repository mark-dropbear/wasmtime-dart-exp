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

    final results = add!.call(store, args: [Val.i32(1), Val.i32(2)]);
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

    expect(() => trapFunc!.call(store, args: []), throwsException);

    trapFunc?.dispose();
    extern?.dispose();
    instance.dispose();
    module.dispose();
  });

  test('host function', () {
    final type = FuncType([ValKind.i32, ValKind.i32], [ValKind.i32]);
    final func = Func.from(store, type, (int a, int b) {
      return a + b;
    });

    final results = func.call(store, args: [Val.i32(1), Val.i32(2)]);
    expect(results, hasLength(1));
    expect(results[0].value, 3);

    func.dispose();
    type.dispose();
  });

  test('call host function from wasm', () {
    final type = FuncType([ValKind.i32, ValKind.i32], [ValKind.i32]);
    final func = Func.from(store, type, (int a, int b) {
      return a + b;
    });

    linker.define(store, 'env', 'add', Extern.fromFunc(func));

    final wat = r'''
      (module
        (import "env" "add" (func $add (param i32 i32) (result i32)))
        (func (export "call_add") (param i32 i32) (result i32)
          local.get 0
          local.get 1
          call $add
        )
      )
    ''';
    final module = Module.fromText(engine, wat);
    final instance = linker.instantiate(store, module);
    final callAdd = instance.getExport(store, 'call_add')?.asFunc;

    expect(callAdd, isNotNull);
    final results = callAdd!.call(store, args: [Val.i32(10), Val.i32(20)]);
    expect(results[0].value, 30);

    func.dispose();
    type.dispose();
    callAdd.dispose();
    instance.dispose();
    module.dispose();
  });

  test('host function trap', () {
    final type = FuncType([], []);
    final func = Func.from(store, type, () {
      throw Exception('oops');
    });

    expect(() => func.call(store), throwsException);

    func.dispose();
    type.dispose();
  });

  test('host function with externref', () {
    final type = FuncType([ValKind.externref], [ValKind.externref]);
    final func = Func.from(store, type, (Object? obj) {
      return obj;
    });

    final obj = 'hello';
    final results = func.call(store, args: [Val.externref(obj)]);
    expect(results, hasLength(1));
    expect(results[0].value, equals(obj));

    func.dispose();
    type.dispose();
  });

  test('host function with funcref', () {
    final type = FuncType([ValKind.funcref], [ValKind.funcref]);
    final func = Func.from(store, type, (Func? f) {
      return f;
    });

    final results = func.call(store, args: [Val.funcref(func)]);
    expect(results, hasLength(1));
    final returnedFunc = results[0].value as Func;
    expect(returnedFunc, equals(func));

    func.dispose();
    type.dispose();
    // returnedFunc shares the same underlying handle ID, but it wraps a new pointer.
    // We should dispose it?
    // Func.fromNative creates a new pointer.
    // So yes, we should dispose it.
    returnedFunc.dispose();
  });
}
