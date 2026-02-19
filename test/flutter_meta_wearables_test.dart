import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_meta_wearables/flutter_meta_wearables.dart';
import 'package:flutter_meta_wearables/src/meta_wearables_platform.dart';
import 'package:flutter_meta_wearables/src/meta_wearables_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockMetaWearablesPlatform extends MetaWearablesPlatform
    with MockPlatformInterfaceMixin {
  bool initialized = false;
  bool registrationStarted = false;
  bool unregistrationStarted = false;
  bool disposed = false;

  final _registrationStateController =
      StreamController<RegistrationState>.broadcast();
  final _devicesController =
      StreamController<List<DeviceIdentifier>>.broadcast();
  final _streamStateController =
      StreamController<StreamSessionState>.broadcast();
  final _videoFrameInfoController =
      StreamController<VideoFrameInfo>.broadcast();
  final _streamErrorsController = StreamController<StreamError>.broadcast();

  @override
  Future<void> initialize() async {
    initialized = true;
  }

  @override
  Future<void> startRegistration() async {
    registrationStarted = true;
  }

  @override
  Future<void> startUnregistration() async {
    unregistrationStarted = true;
  }

  @override
  Stream<RegistrationState> get registrationState =>
      _registrationStateController.stream;

  @override
  Stream<List<DeviceIdentifier>> get devices => _devicesController.stream;

  @override
  Future<PermissionStatus> checkPermissionStatus(
      WearablePermission permission) async {
    return PermissionStatus.granted;
  }

  @override
  Future<PermissionStatus> requestPermission(
      WearablePermission permission) async {
    return PermissionStatus.granted;
  }

  @override
  Future<bool> handleUrl(String url) async {
    return true;
  }

  @override
  Future<Map<String, dynamic>> startStreamSession(
      StreamConfiguration configuration) async {
    return {'sessionId': 'test-session', 'textureId': 1};
  }

  @override
  Future<void> stopStreamSession(String sessionId) async {}

  @override
  Future<PhotoData> capturePhoto(String sessionId) async {
    return PhotoData(
      bytes: Uint8List.fromList([0xFF, 0xD8, 0xFF]),
      width: 1280,
      height: 720,
    );
  }

  @override
  Stream<StreamSessionState> get streamState =>
      _streamStateController.stream;

  @override
  Stream<VideoFrameInfo> get videoFrameInfo =>
      _videoFrameInfoController.stream;

  @override
  Stream<StreamError> get streamErrors => _streamErrorsController.stream;

  @override
  Future<String> mockPairRaybanMeta() async {
    return 'mock-device-1';
  }

  @override
  Future<void> mockUnpairDevice(String deviceId) async {}

  @override
  Future<void> mockDeviceAction(String deviceId, String action) async {}

  @override
  Future<void> mockSetCameraFeed(String deviceId, String filePath) async {}

  @override
  Future<void> mockSetCapturedImage(
      String deviceId, String filePath) async {}

  @override
  Future<void> dispose() async {
    disposed = true;
  }

  void emitRegistrationState(RegistrationState state) {
    _registrationStateController.add(state);
  }

  void emitDevices(List<DeviceIdentifier> devices) {
    _devicesController.add(devices);
  }

  void emitStreamState(StreamSessionState state) {
    _streamStateController.add(state);
  }

  void close() {
    _registrationStateController.close();
    _devicesController.close();
    _streamStateController.close();
    _videoFrameInfoController.close();
    _streamErrorsController.close();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('MethodChannelMetaWearables is the default instance', () {
    expect(
      MetaWearablesPlatform.instance,
      isInstanceOf<MethodChannelMetaWearables>(),
    );
  });

  group('MetaWearables', () {
    late MockMetaWearablesPlatform mockPlatform;

    setUp(() {
      mockPlatform = MockMetaWearablesPlatform();
      MetaWearablesPlatform.instance = mockPlatform;
    });

    tearDown(() {
      mockPlatform.close();
    });

    test('initialize() calls platform initialize', () async {
      final wearables = MetaWearables.instance;
      await wearables.initialize();
      expect(mockPlatform.initialized, isTrue);
    });

    test('startRegistration() calls platform', () async {
      final wearables = MetaWearables.instance;
      await wearables.initialize();
      await wearables.startRegistration();
      expect(mockPlatform.registrationStarted, isTrue);
    });

    test('startUnregistration() calls platform', () async {
      final wearables = MetaWearables.instance;
      await wearables.initialize();
      await wearables.startUnregistration();
      expect(mockPlatform.unregistrationStarted, isTrue);
    });

    test('registrationState stream emits states', () async {
      final wearables = MetaWearables.instance;
      await wearables.initialize();

      final states = <RegistrationState>[];
      final sub = wearables.registrationState.listen(states.add);

      mockPlatform.emitRegistrationState(RegistrationState.registering);
      mockPlatform.emitRegistrationState(RegistrationState.registered);

      await Future.delayed(Duration.zero);

      expect(states, [
        RegistrationState.registering,
        RegistrationState.registered,
      ]);

      await sub.cancel();
    });

    test('devices stream emits device lists', () async {
      final wearables = MetaWearables.instance;
      await wearables.initialize();

      final deviceLists = <List<DeviceIdentifier>>[];
      final sub = wearables.devices.listen(deviceLists.add);

      mockPlatform.emitDevices([
        const DeviceIdentifier(id: 'device-1', name: 'Ray-Ban Meta'),
      ]);

      await Future.delayed(Duration.zero);

      expect(deviceLists.length, 1);
      expect(deviceLists[0].length, 1);
      expect(deviceLists[0][0].id, 'device-1');

      await sub.cancel();
    });

    test('checkPermissionStatus returns granted', () async {
      final wearables = MetaWearables.instance;
      await wearables.initialize();
      final status = await wearables.checkPermissionStatus(
        WearablePermission.camera,
      );
      expect(status, PermissionStatus.granted);
    });

    test('requestPermission returns granted', () async {
      final wearables = MetaWearables.instance;
      await wearables.initialize();
      final status = await wearables.requestPermission(
        WearablePermission.camera,
      );
      expect(status, PermissionStatus.granted);
    });

    test('handleUrl returns true', () async {
      final wearables = MetaWearables.instance;
      await wearables.initialize();
      final result = await wearables.handleUrl('test://callback');
      expect(result, isTrue);
    });

    test('startStreamSession returns session with textureId', () async {
      final wearables = MetaWearables.instance;
      await wearables.initialize();
      final session = await wearables.startStreamSession();
      expect(session.textureId, 1);
    });

    test('capturePhoto returns photo data', () async {
      final wearables = MetaWearables.instance;
      await wearables.initialize();
      final session = await wearables.startStreamSession();
      final photo = await session.capturePhoto();
      expect(photo.width, 1280);
      expect(photo.height, 720);
      expect(photo.bytes.isNotEmpty, isTrue);
    });

    test('mockDeviceKit is available after initialize', () async {
      final wearables = MetaWearables.instance;
      await wearables.initialize();
      expect(wearables.mockDeviceKit, isNotNull);
    });

    test('mockDeviceKit can pair device', () async {
      final wearables = MetaWearables.instance;
      await wearables.initialize();
      final device = await wearables.mockDeviceKit!.pairRaybanMeta();
      expect(device.deviceId, 'mock-device-1');
    });

    test('dispose() calls platform dispose', () async {
      final wearables = MetaWearables.instance;
      await wearables.initialize();
      await wearables.dispose();
      expect(mockPlatform.disposed, isTrue);
    });
  });

  group('Model tests', () {
    test('RegistrationState.fromString', () {
      expect(
        RegistrationState.fromString('registered'),
        RegistrationState.registered,
      );
      expect(
        RegistrationState.fromString('registering'),
        RegistrationState.registering,
      );
      expect(
        RegistrationState.fromString('unknown'),
        RegistrationState.unavailable,
      );
    });

    test('StreamSessionState.fromString', () {
      expect(
        StreamSessionState.fromString('streaming'),
        StreamSessionState.streaming,
      );
      expect(
        StreamSessionState.fromString('waitingForDevice'),
        StreamSessionState.waitingForDevice,
      );
      expect(
        StreamSessionState.fromString('invalid'),
        StreamSessionState.stopped,
      );
    });

    test('StreamError.fromString', () {
      expect(
        StreamError.fromString('deviceNotFound'),
        StreamError.deviceNotFound,
      );
      expect(
        StreamError.fromString('hingesClosed'),
        StreamError.hingesClosed,
      );
      expect(
        StreamError.fromString('invalid'),
        StreamError.unknown,
      );
    });

    test('DeviceIdentifier equality', () {
      const d1 = DeviceIdentifier(id: 'abc', name: 'Device 1');
      const d2 = DeviceIdentifier(id: 'abc', name: 'Device 2');
      const d3 = DeviceIdentifier(id: 'xyz', name: 'Device 1');
      expect(d1, equals(d2));
      expect(d1, isNot(equals(d3)));
    });

    test('DeviceIdentifier fromMap/toMap', () {
      const device = DeviceIdentifier(id: 'test-id', name: 'Test');
      final map = device.toMap();
      expect(map['id'], 'test-id');
      expect(map['name'], 'Test');

      final fromMap = DeviceIdentifier.fromMap(map);
      expect(fromMap, equals(device));
    });

    test('VideoFrameInfo aspectRatio', () {
      const frame = VideoFrameInfo(width: 1920, height: 1080, timestampMs: 0);
      expect(frame.aspectRatio, closeTo(1.778, 0.001));
    });

    test('StreamConfiguration default values', () {
      const config = StreamConfiguration();
      expect(config.videoQuality, VideoQuality.medium);
      expect(config.frameRate, 24);
    });

    test('StreamConfiguration toMap', () {
      const config = StreamConfiguration(
        videoQuality: VideoQuality.high,
        frameRate: 30,
      );
      final map = config.toMap();
      expect(map['videoQuality'], 'high');
      expect(map['frameRate'], 30);
    });

    test('PermissionStatus.fromString', () {
      expect(
        PermissionStatus.fromString('granted'),
        PermissionStatus.granted,
      );
      expect(
        PermissionStatus.fromString('denied'),
        PermissionStatus.denied,
      );
      expect(
        PermissionStatus.fromString('unknown'),
        PermissionStatus.denied,
      );
    });

    test('PhotoData fromMap', () {
      final data = PhotoData.fromMap({
        'bytes': Uint8List.fromList([1, 2, 3]),
        'width': 640,
        'height': 480,
      });
      expect(data.width, 640);
      expect(data.height, 480);
      expect(data.bytes.length, 3);
    });

    test('MetaWearablesException toString', () {
      const e = MetaWearablesException(code: 'test', message: 'error');
      expect(e.toString(), contains('test'));
      expect(e.toString(), contains('error'));
    });
  });
}
