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
      'wasm_store_new',
      'wasmtime_func_new_unchecked',
      'wasmtime_context_get_data',
    }),
    output: Output(
      dartFile: packageRoot.resolve('lib/src/third_party/wasmtime.g.dart'),
    ),
  ).generate();
}
