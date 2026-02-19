import 'meta_wearables_platform.dart';
import 'mock_device_kit.dart';
import 'models/models.dart';
import 'stream_session.dart';

class MetaWearables {
  MetaWearables._();
  static final MetaWearables instance = MetaWearables._();

  MetaWearablesPlatform get _platform => MetaWearablesPlatform.instance;

  bool _initialized = false;
  MockDeviceKit? _mockDeviceKit;

  Future<void> initialize() async {
    await _platform.initialize();
    _initialized = true;
    _mockDeviceKit = MockDeviceKit(platform: _platform);
  }

  void _ensureInitialized() {
    if (!_initialized) {
      throw const MetaWearablesException(
        code: 'not_initialized',
        message: 'MetaWearables.initialize() must be called first.',
      );
    }
  }

  Future<void> startRegistration() async {
    _ensureInitialized();
    await _platform.startRegistration();
  }

  Future<void> startUnregistration() async {
    _ensureInitialized();
    await _platform.startUnregistration();
  }

  Stream<RegistrationState> get registrationState {
    _ensureInitialized();
    return _platform.registrationState;
  }

  Stream<List<DeviceIdentifier>> get devices {
    _ensureInitialized();
    return _platform.devices;
  }

  Future<PermissionStatus> checkPermissionStatus(
      WearablePermission permission) async {
    _ensureInitialized();
    return _platform.checkPermissionStatus(permission);
  }

  Future<PermissionStatus> requestPermission(
      WearablePermission permission) async {
    _ensureInitialized();
    return _platform.requestPermission(permission);
  }

  Future<bool> handleUrl(String url) async {
    _ensureInitialized();
    return _platform.handleUrl(url);
  }

  Future<MetaWearablesStreamSession> startStreamSession({
    StreamConfiguration configuration = const StreamConfiguration(),
  }) async {
    _ensureInitialized();
    final result = await _platform.startStreamSession(configuration);
    return MetaWearablesStreamSession(
      sessionId: result['sessionId'] as String,
      textureId: result['textureId'] as int,
      platform: _platform,
    );
  }

  MockDeviceKit? get mockDeviceKit {
    _ensureInitialized();
    return _mockDeviceKit;
  }

  Future<void> dispose() async {
    if (_initialized) {
      await _platform.dispose();
      _initialized = false;
      _mockDeviceKit = null;
    }
  }
}
