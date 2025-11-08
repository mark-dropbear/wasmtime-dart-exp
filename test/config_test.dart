import 'package:wasmtime/src/config.dart';
import 'package:test/test.dart';

void main() {
  group('Config', () {
    test('can be created and disposed', () {
      final config = Config();
      expect(config, isNotNull);
      config.dispose();
      // Expect no errors on double dispose
      config.dispose();
    });
  });
}
