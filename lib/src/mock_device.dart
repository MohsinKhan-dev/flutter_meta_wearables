import 'meta_wearables_platform.dart';

class MockDevice {
  final String deviceId;
  final MetaWearablesPlatform _platform;

  MockDevice({
    required this.deviceId,
    required MetaWearablesPlatform platform,
  }) : _platform = platform;

  Future<void> powerOn() =>
      _platform.mockDeviceAction(deviceId, 'powerOn');

  Future<void> powerOff() =>
      _platform.mockDeviceAction(deviceId, 'powerOff');

  Future<void> don() => _platform.mockDeviceAction(deviceId, 'don');

  Future<void> doff() => _platform.mockDeviceAction(deviceId, 'doff');

  Future<void> fold() => _platform.mockDeviceAction(deviceId, 'fold');

  Future<void> unfold() =>
      _platform.mockDeviceAction(deviceId, 'unfold');

  Future<void> setCameraFeed(String filePath) =>
      _platform.mockSetCameraFeed(deviceId, filePath);

  Future<void> setCapturedImage(String filePath) =>
      _platform.mockSetCapturedImage(deviceId, filePath);
}
