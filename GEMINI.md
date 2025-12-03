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

The current implementation includes the following classes:

- **`Config`**: A wrapper around the native `wasm_config_t`. It can be used to configure an `Engine`.
- **`Engine`**: A wrapper around the native `wasm_engine_t`. It can be created with a default configuration or with a `Config` object.

## Reference Implementations

The `reference` folder contains Wasmtime wrapping/implementations for other languages, including .NET, Python, and Go. These implementations should be used as authoritative references when developing the Dart package to ensure consistency and correctness.

**Crucially, you must consult these reference implementations to ensure that the Dart implementation and its test suite are of equal or greater quality.** Verify that we are covering similar test cases and handling edge cases in a comparable manner.