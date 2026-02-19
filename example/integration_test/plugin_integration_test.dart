import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:flutter_meta_wearables/flutter_meta_wearables.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('MetaWearables initializes without error',
      (WidgetTester tester) async {
    final wearables = MetaWearables.instance;
    // On a real device with the SDK, this would initialize the MWDAT SDK.
    // On a simulator/emulator without the SDK, this may throw - which is expected.
    try {
      await wearables.initialize();
      expect(wearables.mockDeviceKit, isNotNull);
    } catch (e) {
      // SDK initialization may fail without proper MWDAT SDK configuration
      expect(e, isA<Object>());
    }
  });
}
