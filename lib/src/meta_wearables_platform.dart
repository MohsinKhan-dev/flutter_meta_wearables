import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'meta_wearables_method_channel.dart';
import 'models/models.dart';

abstract class MetaWearablesPlatform extends PlatformInterface {
  MetaWearablesPlatform() : super(token: _token);

  static final Object _token = Object();

  static MetaWearablesPlatform _instance = MethodChannelMetaWearables();

  static MetaWearablesPlatform get instance => _instance;

  static set instance(MetaWearablesPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<void> initialize();
  Future<void> startRegistration();
  Future<void> startUnregistration();
  Stream<RegistrationState> get registrationState;
  Stream<List<DeviceIdentifier>> get devices;
  Future<PermissionStatus> checkPermissionStatus(WearablePermission permission);
  Future<PermissionStatus> requestPermission(WearablePermission permission);
  Future<bool> handleUrl(String url);

  Future<Map<String, dynamic>> startStreamSession(
      StreamConfiguration configuration);
  Future<void> stopStreamSession(String sessionId);
  Future<PhotoData> capturePhoto(String sessionId);
  Stream<StreamSessionState> get streamState;
  Stream<VideoFrameInfo> get videoFrameInfo;
  Stream<StreamError> get streamErrors;

  // MockDeviceKit methods
  Future<String> mockPairRaybanMeta();
  Future<void> mockUnpairDevice(String deviceId);
  Future<void> mockDeviceAction(String deviceId, String action);
  Future<void> mockSetCameraFeed(String deviceId, String filePath);
  Future<void> mockSetCapturedImage(String deviceId, String filePath);

  Future<void> dispose();
}
