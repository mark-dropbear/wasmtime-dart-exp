# Next Steps for Wasmtime Dart API

This document outlines the recommended next steps for the development of the `wasmtime` Dart package, building upon the foundational `Engine` and `Config` classes. The goal is to implement the features necessary to run the "Hello, world!" example from the `README.md`.

## 1. Implement the `Store` Class

A `Store` is a fundamental concept in Wasmtime, representing the instance-specific state and owning all WebAssembly objects. It is a prerequisite for compiling modules and instantiating them.

- **Goal:** Create a `Store` class that wraps the native `wasm_store_t`.
- **C API Functions:**
  - `wasm_store_new`
  - `wasm_store_delete`
- **Dart API:**
  - `Store(Engine engine)` constructor.
  - `void dispose()` method for manual resource management.
- **Action:**
  1. Update `tool/ffigen.dart` to include the `wasm_store_*` functions.
  2. Create `lib/src/store.dart` and implement the `Store` class.
  3. Add unit tests in `test/store_test.dart`.

## 2. Implement the `Module` Class

A `Module` represents a compiled and validated WebAssembly module. This is a critical step to make the package useful.

- **Goal:** Create a `Module` class that can be compiled from WebAssembly Text Format (WAT) or binary Wasm.
- **C API Functions:**
  - `wasmtime_wat2wasm` (to convert WAT to Wasm)
  - `wasmtime_module_new`
  - `wasmtime_module_delete`
  - `wasmtime_module_validate`
- **Dart API:**
  - `Module.fromText(Engine engine, String wat)` factory constructor.
  - `Module.fromBinary(Engine engine, Uint8List wasm)` factory constructor.
  - `void dispose()` method.
- **Action:**
  1. Update `tool/ffigen.dart` with the necessary `wasmtime_module_*` and `wasmtime_wat2wasm` functions.
  2. Create `lib/src/module.dart` and implement the `Module` class.
  3. Add unit tests in `test/module_test.dart`.

## 3. Implement the `Linker` and `Func` Classes

To allow WebAssembly modules to interact with the host (Dart), we need to implement the `Linker` and `Func` classes. The `Linker` is used to define host functions that can be imported by a Wasm module.

- **Goal:** Create `Linker` and `Func` classes to enable host-defined functions.
- **C API Functions:**
  - `wasmtime_linker_new`
  - `wasmtime_linker_delete`
  - `wasmtime_linker_define`
  - `wasmtime_func_new`
  - `wasmtime_func_delete`
- **Dart API:**
  - `Linker(Engine engine)` constructor.
  - `void define(...)` method.
  - `Func.wrap(Store store, Function callback)` factory constructor.
- **Action:**
  1. Update `tool/ffigen.dart` with the `wasmtime_linker_*` and `wasmtime_func_*` functions.
  2. Create `lib/src/linker.dart` and `lib/src/func.dart`.
  3. Implement the `Linker` and `Func` classes.
  4. Add unit tests. This will be more complex and may require a simple Wasm module for testing.

## 4. Implement the `Instance` Class

An `Instance` is the runtime representation of a WebAssembly module. It's created by instantiating a `Module` with a `Store` and a `Linker`.

- **Goal:** Create an `Instance` class that represents an instantiated module.
- **C API Functions:**
  - `wasmtime_linker_instantiate`
  - `wasmtime_instance_export_get`
  - `wasmtime_instance_delete` (if applicable, need to check resource ownership)
- **Dart API:**
  - `Linker.instantiate(Store store, Module module)` method which returns an `Instance`.
  - `Instance.getFunction(Store store, String name)` method.
- **Action:**
  1. Update `tool/ffigen.dart` with the necessary functions.
  2. Create `lib/src/instance.dart`.
  3. Implement the `Instance` class and the `instantiate` method in `Linker`.
  4. Add unit tests.

## 5. Revisit `NativeFinalizer`

Once the core API is functional, we should revisit the `NativeFinalizer` implementation for all classes (`Config`, `Engine`, `Store`, `Module`, etc.). A robust solution for automatic memory management is crucial for a high-quality package. This will likely involve more in-depth debugging of the VM crash encountered previously.

By following these steps, the `wasmtime` package will progressively gain the functionality needed to achieve the vision outlined in the `README.md`.
