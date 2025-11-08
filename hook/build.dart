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
      linkMode: DynamicLoadingBundled(), // Corrected LinkMode
      file: Uri.file(libPath),
    );

    // The hook should place downloaded and generated assets in
    // `BuildInput.sharedOutputDirectory`.
    final sharedOutputDirectory = input.outputDirectoryShared;
    final destination = path.join(sharedOutputDirectory.path, 'libwasmtime.so');
    await File(libPath).copy(destination);

    output.assets.code.add(asset);
  });
}
