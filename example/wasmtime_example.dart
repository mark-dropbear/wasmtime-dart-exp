// Examples use print to show output.
// ignore_for_file: avoid_print

import 'package:wasmtime/wasmtime.dart';

void main() {
  final engine = Engine();
  print('Engine created. Is Pulley: ${engine.isPulley}');
  engine.dispose();

  final config = Config();
  final engineWithConfig = Engine.withConfig(config);
  print('Engine with config created. Is Pulley: ${engineWithConfig.isPulley}');
  engineWithConfig.dispose();
}
