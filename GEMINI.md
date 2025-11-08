# Wasmtime Dart Wrapper

This project is a Dart wrapper for the [Wasmtime](https://wasmtime.dev/) runtime. It uses `dart:ffi` to call into the native Wasmtime library, allowing you to run WebAssembly modules from Dart. Currently, this package is a blank Dart package, but the README file contains a hypothetical idiomatic Dart API for Wasmtime built on top of the C API.

## Building and Running

### Prerequisites

- [Dart SDK](https://dart.dev/get-dart)
- [C/C++ toolchain](https://dart.dev/interop/c-interop#shared-libraries) for building the native library

### Generating FFI bindings

The Dart bindings for the Wasmtime library are generated using the `ffigen` package. To regenerate the bindings, run the following command:

```bash
dart run tool/ffigen.dart
```

This will generate the file `lib/src/third_party/wasmtime.g.dart` based on the configuration in `tool/ffigen.dart`. It should be noted that at present only a small number of functions are set to have bindings generated in order to demonstrate how it works. This list will need to be updated in the future as development progresses.

### Running the example

The project includes a simple example that demonstrates how to use the library. To run the example, execute the following command:

```bash
dart run example/wasmtime_example.dart
```

## Development Conventions

- **FFI Bindings**: The FFI bindings are managed by `ffigen` and configured in `tool/ffigen.dart`. When updating the native library, you may need to update this file and regenerate the bindings.
- **Source Code**: The main source code for the library is located in `lib/src/wasmtime_base.dart`.
- **Tests**: Tests are located in `test/wasmtime_test.dart` and can be run using the `dart test` command.

## Reference Implementations

The `reference` folder contains Wasmtime wrapping/implementations for other languages, including .NET, Python, and Go. These implementations should be used as authoritative references when developing the Dart package to ensure consistency and correctness.