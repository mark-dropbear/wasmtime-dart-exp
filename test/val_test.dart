import 'package:test/test.dart';
import 'package:wasmtime/wasmtime.dart';
import 'package:wasmtime/src/val.dart';
import 'package:wasmtime/src/types.dart';

void main() {
  late Engine engine;
  late Store store;

  setUp(() {
    engine = Engine();
    store = Store(engine);
  });

  tearDown(() {
    store.dispose();
    engine.dispose();
  });

  test('Val.i32', () {
    final val = Val.i32(123);
    expect(val.kind, ValKind.i32);
    expect(val.value, 123);
  });

  test('Val.i64', () {
    final val = Val.i64(1234567890);
    expect(val.kind, ValKind.i64);
    expect(val.value, 1234567890);
  });

  test('Val.f32', () {
    final val = Val.f32(1.5);
    expect(val.kind, ValKind.f32);
    expect(val.value, 1.5);
  });

  test('Val.f64', () {
    final val = Val.f64(1.23456789);
    expect(val.kind, ValKind.f64);
    expect(val.value, 1.23456789);
  });

  test('Val.v128', () {
    final v128 = V128(0x1234567890ABCDEF, 0xFEDCBA0987654321);
    final val = Val.v128(v128);
    expect(val.kind, ValKind.v128);
    expect(val.value, v128);
  });

  test('Val.externref', () {
    final obj = {'foo': 'bar'};
    final val = Val.externref(obj);
    expect(val.kind, ValKind.externref);
    expect(val.value, obj);

    // We can't easily test round-trip without a Wasm module that takes/returns externref.
    // But we can verify that toNative doesn't crash.
    // And we can manually test fromNativeWithStore if we can mock a WasmtimeVal.
    // But WasmtimeVal requires a valid store_id/index from wasmtime.
    // So we need a real integration test for round-trip.
  });

  test('Val.funcref', () {
    // Similarly, we need a real Func from a module to test this fully.
    final val = Val.funcref(null);
    expect(val.kind, ValKind.funcref);
    expect(val.value, isNull);
  });
}
