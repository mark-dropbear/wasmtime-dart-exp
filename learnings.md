# Learnings from creating a Dart package with native code using build hooks

This document captures the key learnings from the process of creating a Dart package that wraps a pre-compiled native C library (`wasmtime`) using Dart's build hooks feature.

## 1. Project Setup

### Dependencies

- For a Dart package that uses build hooks to bundle native code, the following dependencies are required in `pubspec.yaml`:
  - `hooks`: Provides the build hook API.
  - `code_assets`: Defines the `CodeAsset` class used to represent native code assets.
  - `ffi`: Required for interacting with C code.
  - `path`: Useful for path manipulation in the build hook.

- `ffigen` should be added as a `dev_dependency` to generate FFI bindings from C header files.

### `pubspec.yaml` Configuration

- **Crucially**, the dependencies used by the build hook (`hooks`, `code_assets`, `path`, etc.) must be placed in the `dependencies` section of `pubspec.yaml`, not `dev_dependencies`. This is because the build hook is executed by consumer packages, so the hook's dependencies need to be available to them.

- The `ffigen` configuration should be added to `pubspec.yaml` to specify the input header files, the output file for the generated bindings, and the list of functions and types to include.

```yaml
# pubspec.yaml

dependencies:
  code_assets: ^1.0.0
  ffi: ^2.1.4
  hooks: ^1.0.0
  path: ^1.9.0

dev_dependencies:
  ffigen: ^20.0.0
  lints: ^6.0.0
  test: ^1.25.6

ffigen:
  name: WasmtimeBindings
  description: Bindings for wasmtime.
  output: 'lib/src/wasmtime_bindings.dart'
  headers:
    entry-points:
      - 'src/wasmtime-v38.0.3-x86_64-linux-c-api/include/wasmtime.h'
  compiler-opts:
    - '-Isrc/wasmtime-v38.0.3-x86_64-linux-c-api/include'
  functions:
    include:
      - wasm_engine_new
      - wasm_engine_delete
      # ... and other functions
```

## 2. Build Hook (`hook/build.dart`)

- The build hook is a Dart script located in `hook/build.dart` that is executed automatically by the Dart SDK during the build process.

- Its main purpose is to prepare native assets for bundling with the application.

- The entry point is a `main` function that calls the `build` function from the `hooks` package:
  ```dart
  void main(List<String> args) async {
    await build(args, (input, output) async {
      // ... build logic ...
    });
  }
  ```

- For pre-compiled libraries, the build hook's responsibility is to:
  1.  Locate the pre-compiled library file.
  2.  Copy it to the shared output directory: `input.outputDirectoryShared`.
  3.  Register it as a `CodeAsset` with the build output.

- The `CodeAsset` class is used to describe the native code asset. Its constructor requires:
  - `package`: The name of the package.
  - `name`: The name of the asset. This is used to construct the `assetId`.
  - `linkMode`: Specifies how the asset is linked. For a bundled shared library, this should be `DynamicLoadingBundled()`.
  - `file`: A `Uri` pointing to the location of the native library file.

- The `output.assets.code.add()` method is used to register the `CodeAsset` with the build output.

Here is a complete example of a `hook/build.dart` for a pre-compiled library:
```dart
// hook/build.dart
import 'dart:io';

import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';
import 'package:path/path.dart' as path;

void main(List<String> args) async {
  await build(args, (input, output) async {
    final packageRoot = input.packageRoot;

    // Find the wasmtime library.
    final libPath = path.join(
      packageRoot.path,
      'src',
      'wasmtime-v38.0.3-x86_64-linux-c-api',
      'lib',
      'libwasmtime.so',
    );

    final asset = CodeAsset(
      package: 'wasmtime',
      name: 'libwasmtime',
      linkMode: DynamicLoadingBundled(),
      file: Uri.file(libPath),
    );

    // Copy the library to the shared output directory.
    final sharedOutputDirectory = input.outputDirectoryShared;
    final destination = path.join(sharedOutputDirectory.path, 'libwasmtime.so');
    await File(libPath).copy(destination);

    // Register the asset with the build output.
    output.assets.code.add(asset);
  });
}
```

## 3. FFI Bindings

- `ffigen` is a powerful tool for generating Dart FFI bindings from C header files.

- It requires `clang` to be installed and available in the system's `PATH`.

- The `compiler-opts` in the `ffigen` configuration are crucial for providing include paths to the C compiler, so it can find the necessary header files.

## 4. Using the Native Library

- The recommended way to use the bundled native library is with the `@Native` annotation from `dart:ffi`. This is a more modern and robust approach than using `DynamicLibrary.open`.

- The `assetId` for the `@Native` annotation is a `String` with the format `package:<package_name>/<asset_name>`. The `<asset_name>` corresponds to the `name` provided to the `CodeAsset` in the build hook.

- By using `@Native`, the Dart runtime handles loading the library and resolving the symbols automatically.

Example of using `@Native`:
```dart
// lib/src/wasmtime.dart
import 'dart:ffi';

@Native<Pointer<wasm_engine_t> Function()>(assetId: 'package:wasmtime/libwasmtime')
external Pointer<wasm_engine_t> wasm_engine_new();
```

## 5. Troubleshooting

- **`wrong ELF class` error:** This error indicates an architecture mismatch between the native library and the Dart process (e.g., trying to load a 32-bit library in a 64-bit process). The solution is to obtain and use the correct version of the native library for the target architecture.

- **`Unused import` warnings:** If `dart analyze` reports unused imports in `hook/build.dart` (e.g., for `native_toolchain_c` when not compiling from source), they can be safely removed.

- **`non_constant_identifier_names` warnings:** When using FFI, it's common to use `snake_case` for function names to match the C API. These warnings can be suppressed by adding `// ignore_for_file: non_constant_identifier_names` to the top of the Dart file.
