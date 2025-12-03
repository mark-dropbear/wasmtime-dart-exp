# Wasmtime Dart Wrapper

This project is a Dart wrapper for the [Wasmtime](https://wasmtime.dev/) runtime. It uses `dart:ffi` to call into the native Wasmtime library, allowing you to run WebAssembly modules from Dart.

## Building and Running

### Prerequisites

- [Dart SDK](https://dart.dev/get-dart)
- [C/C++ toolchain](https://dart.dev/interop/c-interop#shared-libraries) for building the native library

### Generating FFI bindings

The Dart bindings for the Wasmtime library are generated using the `ffigen` package. To regenerate the bindings, run the following command:

```bash
dart run tool/ffigen.dart
```

This will generate the file `lib/src/third_party/wasmtime.g.dart` based on the configuration in `tool/ffigen.dart`.

### Running the example

The project includes a simple example that demonstrates how to use the library. To run the example, execute the following command:

```bash
dart run example/wasmtime_example.dart
```

## Development Conventions

- **FFI Bindings**: The FFI bindings are managed by `ffigen` and configured in `tool/ffigen.dart`. When updating the native library, you may need to update this file and regenerate the bindings.
- **Source Code**: The main source code for the library is located in `lib/src/`. The main entry point is `lib/wasmtime.dart`.
- **Tests**: Tests are located in `test/` and can be run using the `dart test` command.

## Current Implementation

## Current Implementation

The current implementation includes the following classes and features:

- **Core Classes**:
    - **`Engine`**: A wrapper around the native `wasm_engine_t`.
    - **`Config`**: A wrapper around the native `wasm_config_t`.
    - **`Store`**: A wrapper around the native `wasm_store_t`.
    - **`Module`**: A wrapper around the native `wasm_module_t`.
    - **`Instance`**: A wrapper around the native `wasm_instance_t`.
    - **`Linker`**: A wrapper around the native `wasmtime_linker_t`.
    - **`Extern`**: A wrapper around the native `wasmtime_extern_t`.

- **Function & Type Support**:
    - **`Func`**: Represents a WebAssembly function. Supports calling Wasm functions from Dart and creating host functions (Dart callbacks callable from Wasm).
    - **`Val`**: Represents a WebAssembly value. Supports `i32`, `i64`, `f32`, `f64`, `v128`, `externref`, and `funcref`.
    - **`ValType`**: Represents a WebAssembly value type.
    - **`FuncType`**: Represents a WebAssembly function signature.

- **Advanced Features**:
    - **Host Functions**: Create Wasm functions from Dart callbacks using `Func.from`.
    - **Traps**: Detailed trap information including frames and messages via the `Trap` class.
    - **Reference Types**: Full support for `externref` (holding Dart objects) and `funcref`.
    - **Garbage Collection**: Configured to support Wasm GC.

## Reference Implementations

The `reference` folder contains Wasmtime wrapping/implementations for other languages, including .NET, Python, and Go. These implementations should be used as authoritative references when developing the Dart package to ensure consistency and correctness.

**Crucially, you must consult these reference implementations to ensure that the Dart implementation and its test suite are of equal or greater quality.** Verify that we are covering similar test cases and handling edge cases in a comparable manner.