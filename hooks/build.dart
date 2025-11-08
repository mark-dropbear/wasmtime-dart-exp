import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';
import 'package:path/path.dart' as path;

void main(List<String> args) async {
  await build(args, (input, output) async {
    final packageRoot = input.packageRoot;

    // Find the wasmtime library.
    final libPath = path.join(
      packageRoot.path,
      'third_party',
      'wasmtime',
      'lib',
      'libwasmtime.so',
    );
    final libUri = Uri.file(libPath);

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
  });
}
