import 'package:test/test.dart';
import 'package:wasmtime/src/config.dart';

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
