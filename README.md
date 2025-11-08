# Wastime

A Dart embedding of the Wasmtime project. 

## Notes

This package uses dart:ffi to wrap the native Wasmtime library. In order to determine which functions from the native library you have access to you should update the relevant section in `tool/ffigen.dart` and then run `dart run tool/ffigen.dart` again to automatically generate the correct bindings.

## Hypothetical Usage

Here is a "Hello, world!" example of compiling and running a WebAssembly module from Dart.

This example will:

1. Define a Wasm module that imports a hello function.
2. Export a run function that calls the imported hello.
3. Define the hello function in Dart and provide it to the Wasm instance.
4. Call the exported run function from Dart.

```dart
import 'package:wasmtime/wasmtime.dart';

void main() async {
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
    // Compile the module. Compilation can be async.
    final module = await Module.fromText(engine, wat);

    // Create a store. This holds instance-specific state.
    final store = Store(engine);
    final linker = Linker(engine);

    try {
      // Define the host function that satisfies the Wasm import
      final hostHello = Func.wrap(store, () {
        print('Hello from Dart!');
      });

      // Link the host function
      linker.define(
        store,
        module: '',
        name: 'hello',
        external: hostHello,
      );

      // Instantiate the module
      final instance = await linker.instantiate(store, module);

      // Get the exported 'run' function
      final run = instance.getFunction(store, 'run');

      if (run == null) {
        throw Exception('Export "run" not found');
      }

      // Call the 'run' function.
      // The store is passed as context.
      await run.call(store);

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

## Additional information

TODO: Tell users more about the package: where to find more information, how to 
contribute to the package, how to file issues, what response they can expect 
from the package authors, and more.
