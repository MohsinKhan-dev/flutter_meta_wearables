import 'meta_wearables_platform.dart';
import 'mock_device.dart';

class MockDeviceKit {
  final MetaWearablesPlatform _platform;

  MockDeviceKit({required MetaWearablesPlatform platform})
      : _platform = platform;

  Future<MockDevice> pairRaybanMeta() async {
    final deviceId = await _platform.mockPairRaybanMeta();
    return MockDevice(deviceId: deviceId, platform: _platform);
  }

  Future<void> unpairDevice(MockDevice device) =>
      _platform.mockUnpairDevice(device.deviceId);
}
