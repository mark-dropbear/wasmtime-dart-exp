// Examples use print to show output.
// ignore_for_file: avoid_print

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
      linker.define(store, '', 'hello', Extern.fromFunc(hostHello));

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
