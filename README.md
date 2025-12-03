# Wastime

A Dart embedding of the Wasmtime project. 

## Notes

This package uses dart:ffi to wrap the native Wasmtime library. In order to determine which functions from the native library you have access to you should update the relevant section in `tool/ffigen.dart` and then run `dart run tool/ffigen.dart` again to automatically generate the correct bindings.

## Usage

Here is a "Hello, world!" example of compiling and running a WebAssembly module from Dart.

This example will:

1. Define a Wasm module that imports a hello function.
2. Export a run function that calls the imported hello.
3. Define the hello function in Dart and provide it to the Wasm instance.
4. Call the exported run function from Dart.

```dart
import 'package:wasmtime/wasmtime.dart';

void main() {
  // Define the module in WebAssembly Text Format (WAT)
  const wat = r'''
    (module
      (func $hello (import "" "hello"))
      (func (export "run") (call $hello))
    )
  ''';

  // Create an engine. This is a long-lived object that can be reused.
  final engine = Engine();

  try {
    // Compile the module.
    final module = Module.fromText(engine, wat);

    // Create a store. This holds instance-specific state.
    final store = Store(engine);
    final linker = Linker(engine);

    try {
      // Define the host function that satisfies the Wasm import
      final funcType = FuncType([], []);
      final hostHello = Func.from(store, funcType, () {
        print('Hello from Dart!');
      });

      // Link the host function
      linker.define(
        store,
        '',
        'hello',
        Extern.fromFunc(hostHello),
      );

      // Instantiate the module
      final instance = linker.instantiate(store, module);

      // Get the exported 'run' function
      final run = instance.getExport(store, 'run')?.asFunc;

      if (run == null) {
        throw Exception('Export "run" not found');
      }

      // Call the 'run' function.
      // The store is passed as context.
      run.call(store);

    } finally {
      // Dispose of store-specific resources
      store.dispose();
      linker.dispose();
    }
  } finally {
    // The engine must be disposed to free native resources
    engine.dispose();
  }
}
```

## Features

- **Wasmtime Runtime**: Full access to the Wasmtime runtime via `dart:ffi`.
- **Module Compilation**: Compile Wasm modules from text (WAT) or binary.
- **Instance Management**: Instantiate modules and manage their lifecycle.
- **Host Functions**: Call Dart functions from WebAssembly.
- **Reference Types**: Support for `externref` (Dart objects) and `funcref`.
- **Traps**: Detailed error reporting with stack traces.
- **Garbage Collection**: Integrated with Wasm GC.

## Additional information

TODO: Tell users more about the package: where to find more information, how to 
contribute to the package, how to file issues, what response they can expect 
from the package authors, and more.
