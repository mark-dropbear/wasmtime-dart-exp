// Copyright (c) 2025, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:ffigen/ffigen.dart';

void main() {
  final packageRoot = Platform.script.resolve('../');
  FfiGenerator(
    headers: Headers(
      entryPoints: [
        packageRoot.resolve('third_party/wasmtime/include/wasmtime.h'),
      ],
      compilerOptions: ['-Ithird_party/wasmtime/include'],
    ),
    functions: Functions.includeSet({
      'wasm_engine_new',
      'wasm_engine_delete',
      'wasm_config_new',
      'wasm_config_delete',
      'wasm_engine_new_with_config',
      'wasmtime_engine_increment_epoch',
      'wasmtime_engine_is_pulley',
      'wasmtime_store_new',
      'wasmtime_store_delete',
      'wasmtime_store_context',
      'wasmtime_context_gc',
      'wasmtime_context_get_data',
      'wasmtime_module_new',
      'wasmtime_module_delete',
      'wasmtime_module_validate',
      'wasmtime_wat2wasm',
      'wasm_byte_vec_new',
      'wasm_byte_vec_delete',
    }),
    output: Output(
      dartFile: packageRoot.resolve('lib/src/third_party/wasmtime.g.dart'),
    ),
    structs: Structs.includeSet({'wasm_byte_vec_t'}),
  ).generate();
}
