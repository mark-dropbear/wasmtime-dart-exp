# Feature Specification

## Download Feature

### What is the problem that we are trying to solve?

At the moment, we manually download and copy the Wasmtime C library to the `third_party/wasmtime/` directory. In addition to being a manual process that could be automated, the files we are using are pre-compiled and platform specific which means needing to redo the entire process for each platform. The goal is to take advantage of the new Hooks feature that landed in Dart 3.10 to automate this process and make it easier to maintain. 

### Backgound Information About Hooks
Hooks are a new feature in Dart 3.10 which allow you to do things such as compile or download native assets (code written in other languages that are compiled into machine code), and then call these assets from the Dart code of a package.

Hooks are Dart scripts placed in the hook/ directory of your Dart package. They have a predefined format for their input and output, which allows the Dart SDK to:

1. Discover the hooks.
2. Execute the hooks with the necessary input.
3. Consume the output produced by the hooks.

#### Build Hooks
With build hooks, a package can do things such as compile or download native assets such as C or Rust libraries. Afterwards, these assets can be called from the Dart code of a package.

A package's build hook is automatically invoked by the Dart SDK at an appropriate time during the build process. Build hooks are run in parallel with Dart compilation and might do longer running operations such as downloading or calling a native compiler.

Use the `build` function to parse the hook input with `BuildInput` and then write the hook output with `BuildOutputBuilder`. The hook should place downloaded and generated assets in `BuildInput.sharedOutputDirectory`.

The assets produced for your package might depend on `assets` or `metadata` produced by the build hooks from the packages in the direct dependencies in the pubspec. Therefore, build hooks are run in the order of dependencies in the pubspec, and cyclic dependencies between packages are not supported when using hooks.

#### Assets
Assets are the files that are produced by a hook and then bundled in a Dart application. Assets can be accessed at run time from the Dart code. Currently, the Dart SDK can use the `CodeAsset` type, but more asset types are planned. To learn more, see the following.

#### CodeAsset type
A `CodeAsset` represents a code asset. A code asset is a dynamic library compiled from a language other than Dart, such as C, C++, Rust, or Go. `CodeAsset` is part of the `code_asset` package. APIs provided by code assets are accessed at run time through corresponding external Dart members annotated with the `@Native` annotation from `dart:ffi`.

### Where we are starting from
We are *already* successfully using the hooks feature in this package at the moment, however, we are not currently compiling the library from source. We are instead using the precompiled library from the `third_party/wasmtime/lib` directory which is at the heart of our problem. You can see the current implementation in the `hook/build.dart` file or shown below:

```dart
// filename: hook/build.dart
import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';
import 'package:path/path.dart' as path;

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
    }
  });
}
```

We also have another key file in `tool/ffigen.dart` which is where we identify the C headers that we need to use the `ffi` package to automatically generate the Dart bindings for the selected functions and structs. It currently looks like shown below:

```dart
// filename: tools/ffigen.dart
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
```

It is not anticipated that this file would change in any substantial fashion in itself but it is expected that the list of functions and structs that we need to bind to will change over time as the wasmtime library evolves.

The `hook/build.dart` file however may well be updated to look at compiling the code from source in the future but remains *out of scope* for this feature as it required a Rust toolchain to build the underlying Wasmtime project which is not currently well supported by the Dart hooks feature.

### Instructive Example
This section shows an example of a library depending on prebuilt assets which are downloaded in the build hook.
- `hook/build.dart` downloads the prebuilt assets.
- `lib/` contains Dart code which uses the assets.

This example was written by the Dart team themselves as a way to help demonstrate the new hooks feature and how it might be used in a similar scenario to the one we are looking at here in this feature.

#### hook/build.dart

```dart
// filename: hook/build.dart

import 'dart:io';

import 'package:code_assets/code_assets.dart';
import 'package:download_asset/src/hook_helpers/c_build.dart';
import 'package:download_asset/src/hook_helpers/download.dart';
import 'package:download_asset/src/hook_helpers/hashes.dart';
import 'package:hooks/hooks.dart';

void main(List<String> args) async {
  await build(args, (input, output) async {
    final localBuild = input.userDefines['local_build'] as bool? ?? false;
    if (localBuild) {
      await runBuild(input, output);
    } else {
      final targetOS = input.config.code.targetOS;
      final targetArchitecture = input.config.code.targetArchitecture;
      final iOSSdk = targetOS == OS.iOS
          ? input.config.code.iOS.targetSdk
          : null;
      final outputDirectory = Directory.fromUri(input.outputDirectory);
      final file = await downloadAsset(
        targetOS,
        targetArchitecture,
        iOSSdk,
        outputDirectory,
      );
      final fileHash = await hashAsset(file);
      final expectedHash =
          assetHashes[input.config.code.targetOS.dylibFileName(
            createTargetName(
              targetOS.name,
              targetArchitecture.name,
              iOSSdk?.type,
            ),
          )];
      if (fileHash != expectedHash) {
        throw Exception(
          'File $file was not downloaded correctly. '
          'Found hash $fileHash, expected $expectedHash.',
        );
      }
      output.assets.code.add(
        CodeAsset(
          package: input.packageName,
          name: 'native_add.dart',
          linkMode: DynamicLoadingBundled(),
          file: file.uri,
        ),
      );
    }
  });
}
```

#### lib/src/hook_helpers/c_build.dart

```dart
// filename: lib/src/hook_helpers/c_build.dart
import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';
import 'package:native_toolchain_c/native_toolchain_c.dart';

/// Builds the C code for the native_add example.
Future<void> runBuild(BuildInput input, BuildOutputBuilder output) async {
  final name = createTargetName(
    input.config.code.targetOS.name,
    input.config.code.targetArchitecture.name,
    input.config.code.targetOS == OS.iOS
        ? input.config.code.iOS.targetSdk.type
        : null,
  );
  final cbuilder = CBuilder.library(
    name: name,
    assetName: 'native_add.dart',
    sources: ['src/native_add.c'],
  );
  await cbuilder.run(input: input, output: output);
}

/// Creates a target name based on the OS, architecture, and iOS SDK.
///
/// For example, `native_add_ios_arm64_iphonesimulator` or
/// `native_add_windows_x64`.
String createTargetName(String osString, String architecture, String? iOSSdk) {
  var targetName = 'native_add_${osString}_$architecture';
  if (iOSSdk != null) {
    targetName += '_$iOSSdk';
  }
  return targetName;
}
```

#### lib/src/hook_helpers/download.dart

```dart
// filename: lib/src/hook_helpers/download.dart
import 'dart:io';

import 'package:code_assets/code_assets.dart';
import 'package:crypto/crypto.dart';

import 'c_build.dart';
import 'version.dart';

/// Constructs the download URI for a given [target] file name.
Uri downloadUri(String target) => Uri.parse(
  'https://github.com/dart-lang/native/releases/download/$version/$target',
);

/// Downloads an asset for the specified [targetOS], [targetArchitecture], and
/// [iOSSdk].
Future<File> downloadAsset(
  OS targetOS,
  Architecture targetArchitecture,
  IOSSdk? iOSSdk,
  Directory outputDirectory,
) async {
  final targetName = targetOS.dylibFileName(
    createTargetName(targetOS.name, targetArchitecture.name, iOSSdk?.type),
  );
  final uri = downloadUri(targetName);
  final client = HttpClient()
    // Respect the http(s)_proxy environment variables.
    ..findProxy = HttpClient.findProxyFromEnvironment;
  final request = await client.getUrl(uri);
  final response = await request.close();
  if (response.statusCode != 200) {
    throw ArgumentError('The request to $uri failed.');
  }
  final library = File.fromUri(outputDirectory.uri.resolve(targetName));
  await library.create();
  await response.pipe(library.openWrite());
  return library;
}

/// Computes the MD5 hash of the given [assetFile].
Future<String> hashAsset(File assetFile) async {
  // TODO(dcharkes): Should this be a strong hash to not only check for download
  // integrity but also safeguard against tampering? This would protected
  // against the case where the binary hoster is compromised but pub is not
  // compromised.
  final fileHash = md5.convert(await assetFile.readAsBytes()).toString();
  return fileHash;
}
```

#### lib/src/hook_helpers/hashes.dart

```dart
// filename: lib/src/hook_helpers/hashes.dart
const assetHashes = <String, String>{
  'libnative_add_android_arm.so': '2c38f3edc805a399dad866d619f9157d',
  'libnative_add_android_arm64.so': 'c4f0d8c4c50d1e83592e499e7434b967',
  'libnative_add_android_ia32.so': 'e3277144d97bd2c54beee581ed7e6665',
  'libnative_add_android_riscv64.so': '8c2576cbe75c9a23f2532ff895f94f76',
  'libnative_add_android_x64.so': '9a7bec53e1591091669ecd2bd20911d1',
  'libnative_add_ios_arm64_iphoneos.dylib': '1bf1473cacb7fd2778fc5bb28f0b61a2',
  'libnative_add_ios_arm64_iphonesimulator.dylib':
      'cdddffc0787e6a3a846affcb05fac3a8',
  'libnative_add_ios_x64_iphonesimulator.dylib':
      '4aea6d631350540d50452ac2bdd1a422',
  'libnative_add_linux_arm.so': '1a5b9e4b459e13ee85c148582b9b2252',
  'libnative_add_linux_arm64.so': '2b3d736e0c0ac1e1537bc43bd9b82cad',
  'libnative_add_linux_ia32.so': 'ed6e130e53fa18eab5572ed106cdaab1',
  'libnative_add_linux_riscv64.so': '7fa82325ba7803a0443ca27e3300e7f9',
  'libnative_add_linux_x64.so': 'f7af8d1547cdfb150a73d513a7957999',
  'libnative_add_macos_arm64.dylib': 'f0804ff4b55126996c180114f25ca5bd',
  'libnative_add_macos_x64.dylib': 'b62263803dceb3c23508cb909b5a5583',
  'native_add_windows_arm64.dll': '7aa6f5e0275ba1b94cd5b7356f89ef04',
  'native_add_windows_ia32.dll': 'ab57b5504d92b5b5dc09732d990fd5e7',
  'native_add_windows_x64.dll': 'be9ba2125800aa2e3481a759b1845a50',
};
```

#### lib/src/hook_helpers/target_versions.dart

```dart
// filename: lib/src/hook_helpers/target_versions.dart

/// The target Android NDK API level for compilation.
const androidTargetNdkApi = 30;

/// The target macOS version for compilation.
const int macOSTargetVersion = 13;

/// The target iOS version for compilation.
const iOSTargetVersion = 16;
```

#### lib/src/hook_helpers/targets.dart

```dart
// filename: lib/src/hook_helpers/targets.dart

// THIS FILE IS AUTOGENERATED. TO UPDATE, RUN
//
//    dart tool/generate_asset_hashes.dart
//

import 'package:code_assets/code_assets.dart';

/// A list of supported target combinations of OS, architecture, and iOS SDK.
///
/// Used to determine which assets to download or build.
const supportedTargets = [
  (OS.android, Architecture.arm, null),
  (OS.android, Architecture.arm64, null),
  (OS.android, Architecture.ia32, null),
  (OS.android, Architecture.riscv64, null),
  (OS.android, Architecture.x64, null),
  (OS.iOS, Architecture.arm64, IOSSdk.iPhoneOS),
  (OS.iOS, Architecture.arm64, IOSSdk.iPhoneSimulator),
  (OS.iOS, Architecture.x64, IOSSdk.iPhoneSimulator),
  (OS.linux, Architecture.arm, null),
  (OS.linux, Architecture.arm64, null),
  (OS.linux, Architecture.ia32, null),
  (OS.linux, Architecture.riscv64, null),
  (OS.linux, Architecture.x64, null),
  (OS.macOS, Architecture.arm64, null),
  (OS.macOS, Architecture.x64, null),
  (OS.windows, Architecture.arm64, null),
  (OS.windows, Architecture.ia32, null),
  (OS.windows, Architecture.x64, null),
];
```

#### lib/src/hook_helpers/version.dart

```dart
// filename: lib/src/hook_helpers/version.dart

import 'download.dart';
import 'hashes.dart';

/// The GitHub release to use for downloading assets.
///
/// Assets are downloaded from [downloadUri].
///
/// After changing [assetHashes] must be updated.
const version = 'download_asset-prebuild-assets-v0.1.0-try-3';
```

#### lib/native_add.dart

```dart
// filename: lib/native_add.dart

// AUTO GENERATED FILE, DO NOT EDIT.
//
// Generated by `package:ffigen`.
// ignore_for_file: type=lint
import 'dart:ffi' as ffi;

@ffi.Native<ffi.Int32 Function(ffi.Int32, ffi.Int32)>()
external int add(int a, int b);
```

#### src/native_add.c

```c
// filename: src/native_add.c

#include "native_add.h"

int32_t add(int32_t a, int32_t b) { return a + b; }
```

#### src/native_add.h

```c
// filename: src/native_add.h

#include <stdint.h>

#if _WIN32
#define MYLIB_EXPORT __declspec(dllexport)
#else
#define MYLIB_EXPORT
#endif

MYLIB_EXPORT int32_t add(int32_t a, int32_t b);
```

#### tool/build.dart

```dart
// filename: tool/build.dart
import 'dart:io';

import 'package:args/args.dart';
import 'package:code_assets/code_assets.dart';
import 'package:download_asset/src/hook_helpers/c_build.dart';
import 'package:download_asset/src/hook_helpers/target_versions.dart';
import 'package:hooks/hooks.dart';

void main(List<String> args) async {
  final (os: os, architecture: architecture, iOSSdk: iOSSdk) = parseArguments(
    args,
  );
  final input = createBuildInput(os, architecture, iOSSdk);
  final output = BuildOutputBuilder();
  await runBuild(input, output);
}

({String architecture, String os, String? iOSSdk}) parseArguments(
  List<String> args,
) {
  final parser = ArgParser()
    ..addOption(
      'architecture',
      abbr: 'a',
      allowed: Architecture.values.map((a) => a.name),
      mandatory: true,
    )
    ..addOption(
      'os',
      abbr: 'o',
      allowed: OS.values.map((a) => a.name),
      mandatory: true,
    )
    ..addOption(
      'iossdk',
      abbr: 'i',
      allowed: IOSSdk.values.map((a) => a.type),
      help: 'Required if OS is iOS.',
    );
  final argResults = parser.parse(args);

  final os = argResults.option('os');
  final architecture = argResults.option('architecture');
  final iOSSdk = argResults.option('iossdk');
  if (os == null ||
      architecture == null ||
      (os == OS.iOS.name && iOSSdk == null)) {
    print(parser.usage);
    exit(1);
  }
  return (os: os, architecture: architecture, iOSSdk: iOSSdk);
}

BuildInput createBuildInput(
  String osString,
  String architecture,
  String? iOSSdk,
) {
  final packageRoot = Platform.script.resolve('..');
  final outputDirectoryShared = packageRoot.resolve(
    '.dart_tool/download_asset/shared/',
  );
  final outputFile = packageRoot.resolve(
    '.dart_tool/download_asset/output.json',
  );

  final os = OS.fromString(osString);
  final inputBuilder = BuildInputBuilder()
    ..setupShared(
      packageRoot: packageRoot,
      packageName: 'download_asset',
      outputFile: outputFile,
      outputDirectoryShared: outputDirectoryShared,
    )
    ..config.setupBuild(linkingEnabled: false)
    ..addExtension(
      CodeAssetExtension(
        targetArchitecture: Architecture.fromString(architecture),
        targetOS: os,
        linkModePreference: LinkModePreference.dynamic,
        android: os != OS.android
            ? null
            : AndroidCodeConfig(targetNdkApi: androidTargetNdkApi),
        iOS: os != OS.iOS
            ? null
            : IOSCodeConfig(
                targetSdk: IOSSdk.fromString(iOSSdk!),
                targetVersion: iOSTargetVersion,
              ),
        macOS: MacOSCodeConfig(targetVersion: macOSTargetVersion),
      ),
    );
  return inputBuilder.build();
}
```

#### tool/generate_asset_hashes.dart

```dart
// filename: tool/generate_asset_hashes.dart
import 'dart:io';

import 'package:download_asset/src/hook_helpers/download.dart';
import 'package:download_asset/src/hook_helpers/hashes.dart';
import 'package:download_asset/src/hook_helpers/targets.dart';

/// Regenerates [assetHashes].
Future<void> main(List<String> args) async {
  final assetsDir = Directory.fromUri(
    Platform.script.resolve('../.dart_tool/download_asset/'),
  );
  await assetsDir.delete(recursive: true);
  await assetsDir.create(recursive: true);
  await Future.wait([
    for (final (targetOS, targetArchitecture, iOSSdk) in supportedTargets)
      downloadAsset(targetOS, targetArchitecture, iOSSdk, assetsDir),
  ]);
  final assetFiles =
      assetsDir.listSync(recursive: true).whereType<File>().toList()
        ..sort((f1, f2) => f1.path.compareTo(f2.path));
  final assetHashes = <String, String>{};
  for (final assetFile in assetFiles) {
    final fileHash = await hashAsset(assetFile);
    final target = assetFile.uri.pathSegments.lastWhere((e) => e.isNotEmpty);
    assetHashes[target] = fileHash;
  }

  await writeHashesFile(assetHashes);
}

Future<void> writeHashesFile(Map<String, String> assetHashes) async {
  final hashesFile = File.fromUri(
    Platform.script.resolve('../lib/src/hook_helpers/hashes.dart'),
  );
  await hashesFile.create(recursive: true);
  final buffer = StringBuffer();
  buffer.write('''
// THIS FILE IS AUTOGENERATED. TO UPDATE, RUN
//
//    dart --enable-experiment=native-assets tool/generate_asset_hashes.dart
//

const assetHashes = <String, String>{
''');
  for (final hash in assetHashes.entries) {
    buffer.write("  '${hash.key}': '${hash.value}',\n");
  }
  buffer.write('''
};
''');
  await hashesFile.writeAsString(buffer.toString());
  await Process.run(Platform.executable, ['format', hashesFile.path]);
}
```

### Wasmtime Specific Examples in Other Languages
As this project contains a reference folder for other languages, we can look at the Python example to see how it is used when they need to download precompiled libraries for specific platforms. The Python example can be found in `reference/python/ci/download-wasmtime.py` and is also included below:

```python
# Helper script to download a precompiled binary of the wasmtime dll for the
# current platform.

import io
import platform
import shutil
import sys
import tarfile
import urllib.request
import zipfile
from pathlib import Path

# set to "dev" to download the latest or pick a tag from
# https://github.com/bytecodealliance/wasmtime/tags
WASMTIME_VERSION = "dev"


def main(platform, arch):
    is_zip = False
    version = WASMTIME_VERSION

    if arch == 'AMD64':
        arch = 'x86_64'
    if arch == 'arm64' or arch == 'ARM64':
        arch = 'aarch64'
    dirname = '{}-{}'.format(platform, arch)
    if platform == 'linux' or platform == 'musl':
        filename = 'wasmtime-{}-{}-{}-c-api.tar.xz'.format(version, arch, platform)
        libname = '_libwasmtime.so'
        dirname = 'linux-{}'.format(arch)
    elif platform == 'win32':
        filename = 'wasmtime-{}-{}-windows-c-api.zip'.format(version, arch)
        is_zip = True
        libname = '_wasmtime.dll'
    elif platform == 'mingw':
        filename = 'wasmtime-{}-{}-mingw-c-api.zip'.format(version, arch)
        is_zip = True
        libname = '_wasmtime.dll'
    elif platform == 'darwin':
        filename = 'wasmtime-{}-{}-macos-c-api.tar.xz'.format(version, arch)
        libname = '_libwasmtime.dylib'
    elif platform == 'android':
        filename = 'wasmtime-{}-{}-android-c-api.tar.xz'.format(version, arch)
        libname = '_libwasmtime.so'
        dirname = 'android-{}'.format(arch)
    else:
        raise RuntimeError("unknown platform: " + sys.platform)

    url = 'https://github.com/bytecodealliance/wasmtime/releases/download/{}/'.format(version)
    url += filename
    print('Download', url)
    dst = Path('wasmtime') / dirname / libname
    try:
        shutil.rmtree(dst.parent)
    except Exception:
        pass
    try:
        shutil.rmtree(Path('wasmtime/include'))
    except Exception:
        pass

    with urllib.request.urlopen(url) as f:
        contents = f.read()

    def final_loc(name):
        parts = name.split('include/')
        if '/min/' in name:
            return None
        elif len(parts) > 1 and name.endswith('.h'):
            return Path('wasmtime') / 'include' / parts[1]
        elif name.endswith('.dll') or name.endswith('.so') or name.endswith('.dylib'):
            if '-min.' in name:
                return None
            return dst
        else:
            return None

    if is_zip:
        t = zipfile.ZipFile(io.BytesIO(contents))
        for member in t.namelist():
            loc = final_loc(member)
            if not loc:
                continue
            loc.parent.mkdir(parents=True, exist_ok=True)
            print(f'{member} => {loc}')
            contents = t.read(member)
            with open(loc, "wb") as f:
                f.write(contents)
    else:
        t = tarfile.open(fileobj=io.BytesIO(contents))
        for member in t.getmembers():
            loc = final_loc(member.name)
            if not loc:
                continue
            loc.parent.mkdir(parents=True, exist_ok=True)
            print(f'{member.name} => {loc}')
            contents = t.extractfile(member).read()
            with open(loc, "wb") as f:
                f.write(contents)

    if not dst.exists():
        raise RuntimeError("failed to find dynamic library")


if __name__ == '__main__':
    if len(sys.argv) > 2:
        main(sys.argv[1], sys.argv[2])
    else:
        main(sys.platform, platform.machine())

```