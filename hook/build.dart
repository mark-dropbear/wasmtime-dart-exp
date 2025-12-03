import 'dart:io';
import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';
import 'package:path/path.dart' as path;
import 'package:wasmtime/src/hook_helpers/download_wasmtime.dart';

void main(List<String> args) async {
  await build(args, (input, output) async {
    if (input.config.buildCodeAssets) {
      final packageRoot = input.packageRoot;

      // Find the wasmtime library.
      final libPath = path.join(
        packageRoot.path,
        'third_party',
        'wasmtime',
        'lib',
        _getLibName(input.config.code.targetOS),
      );
      final libUri = Uri.file(libPath);
      final libFile = File(libPath);

      if (!libFile.existsSync()) {
        stdout.writeln(
          'Wasmtime library not found at $libPath. Downloading...',
        );
        await downloadWasmtime(
          packageRoot.path,
          targetOS: input.config.code.targetOS,
          targetArch: input.config.code.targetArchitecture,
        );
      }

      output.assets.code.add(
        // Asset ID: "package:wasmtime/src/third_party/wasmtime.g.dart"
        CodeAsset(
          package: 'wasmtime',
          name: 'src/third_party/wasmtime.g.dart',
          linkMode: DynamicLoadingBundled(),
          file: libUri,
        ),
      );
      output.dependencies.add(libUri);
    }
  });
}

String _getLibName(OS os) {
  if (os == OS.windows) return 'wasmtime.dll';
  if (os == OS.macOS) return 'libwasmtime.dylib';
  return 'libwasmtime.so';
}
