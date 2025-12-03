import 'dart:io';
import 'package:archive/archive.dart';
import 'package:archive/archive_io.dart';
import 'package:code_assets/code_assets.dart';
import 'package:path/path.dart' as path;

// Set to a specific version or "dev" to download the latest.
/// The version of Wasmtime to download.
const wasmtimeVersion = 'v39.0.1';

/// Downloads the Wasmtime binary for the specified [targetOS] and [targetArch].
///
/// The binary is extracted to `third_party/wasmtime/` within the [packageRoot].
Future<void> downloadWasmtime(
  String packageRoot, {
  required OS targetOS,
  required Architecture targetArch,
}) async {
  final target = _determineTarget(targetOS, targetArch);
  final filename = target.filename;
  final url =
      'https://github.com/bytecodealliance/wasmtime/releases/download/$wasmtimeVersion/$filename';

  stdout.writeln('Downloading Wasmtime from $url...');

  final client = HttpClient();
  final request = await client.getUrl(Uri.parse(url));
  final response = await request.close();

  if (response.statusCode != 200) {
    throw Exception(
      'Failed to download Wasmtime: ${response.statusCode} ${response.reasonPhrase}',
    );
  }

  final tempDir = Directory.systemTemp.createTempSync('wasmtime_download');
  final archiveFile = File(path.join(tempDir.path, filename));
  await response.pipe(archiveFile.openWrite());

  stdout.writeln('Extracting to third_party/wasmtime...');
  final thirdPartyDir = Directory(
    path.join(packageRoot, 'third_party', 'wasmtime'),
  );

  // Clean up existing directories
  final libDir = Directory(path.join(thirdPartyDir.path, 'lib'));
  final includeDir = Directory(path.join(thirdPartyDir.path, 'include'));
  if (libDir.existsSync()) libDir.deleteSync(recursive: true);
  if (includeDir.existsSync()) includeDir.deleteSync(recursive: true);

  // Ensure third_party/wasmtime exists
  thirdPartyDir.createSync(recursive: true);

  try {
    if (filename.endsWith('.zip')) {
      await _extractZip(archiveFile, thirdPartyDir, target);
    } else if (filename.endsWith('.tar.xz')) {
      await _extractTarXz(archiveFile, thirdPartyDir, target);
    } else {
      throw Exception('Unsupported archive format: $filename');
    }
  } finally {
    tempDir.deleteSync(recursive: true);
  }

  stdout.writeln('Wasmtime downloaded and extracted successfully.');
}

class _Target {
  final String filename;
  final String libName;

  _Target({required this.filename, required this.libName});
}

_Target _determineTarget(OS os, Architecture arch) {
  String archString;
  if (arch == Architecture.x64) {
    archString = 'x86_64';
  } else if (arch == Architecture.arm64) {
    archString = 'aarch64';
  } else {
    throw Exception('Unsupported architecture: $arch');
  }

  if (os == OS.linux) {
    return _Target(
      filename: 'wasmtime-$wasmtimeVersion-$archString-linux-c-api.tar.xz',
      libName: 'libwasmtime.so',
    );
  } else if (os == OS.windows) {
    return _Target(
      filename: 'wasmtime-$wasmtimeVersion-$archString-windows-c-api.zip',
      libName: 'wasmtime.dll',
    );
  } else if (os == OS.macOS) {
    return _Target(
      filename: 'wasmtime-$wasmtimeVersion-$archString-macos-c-api.tar.xz',
      libName: 'libwasmtime.dylib',
    );
  } else {
    throw Exception('Unsupported OS: $os');
  }
}

Future<void> _extractZip(
  File zipFile,
  Directory destination,
  _Target target,
) async {
  final bytes = zipFile.readAsBytesSync();
  final archive = ZipDecoder().decodeBytes(bytes);
  _extractArchive(archive, destination, target);
}

Future<void> _extractTarXz(
  File tarFile,
  Directory destination,
  _Target target,
) async {
  final bytes = tarFile.readAsBytesSync();
  final xzBytes = XZDecoder().decodeBytes(bytes);
  final archive = TarDecoder().decodeBytes(xzBytes);
  _extractArchive(archive, destination, target);
}

void _extractArchive(Archive archive, Directory destination, _Target target) {
  for (final file in archive) {
    final filename = file.name;
    if (file.isFile) {
      final finalPath = _determineFinalPath(filename, destination, target);
      if (finalPath != null) {
        final f = File(finalPath);
        f.parent.createSync(recursive: true);
        f.writeAsBytesSync(file.content as List<int>);
      }
    }
  }
}

String? _determineFinalPath(
  String name,
  Directory destination,
  _Target target,
) {
  // Logic from python script:
  // if '/min/' in name: return None
  // if name.endsWith('.h') and len(parts) > 1: return include/parts[1]
  // if name.endsWith(libName): return lib/libName

  if (name.contains('/min/')) return null;

  if (name.endsWith('.h')) {
    final parts = name.split('include/');
    if (parts.length > 1) {
      return path.join(destination.path, 'include', parts[1]);
    }
  } else if (name.endsWith(target.libName)) {
    // The python script puts the lib in `wasmtime/dirname/libname`?
    // Wait, python script: `dst = Path('wasmtime') / dirname / libname`
    // And `dirname` varies.
    // But for Dart FFI, we usually want it in a known location or we just need to know where it is.
    // The `hook/build.dart` expects `third_party/wasmtime/lib/libwasmtime.so`.
    // So we should flatten it to `lib/libwasmtime.so`.

    return path.join(destination.path, 'lib', target.libName);
  }

  return null;
}
