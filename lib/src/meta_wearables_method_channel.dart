import 'package:flutter/services.dart';

import 'meta_wearables_platform.dart';
import 'models/models.dart';

class MethodChannelMetaWearables extends MetaWearablesPlatform {
  static const _methodChannel =
      MethodChannel('com.meta.wearable.flutter/methods');
  static const _registrationStateChannel =
      EventChannel('com.meta.wearable.flutter/registrationState');
  static const _devicesChannel =
      EventChannel('com.meta.wearable.flutter/devices');
  static const _streamStateChannel =
      EventChannel('com.meta.wearable.flutter/streamState');
  static const _videoFrameInfoChannel =
      EventChannel('com.meta.wearable.flutter/videoFrameInfo');
  static const _streamErrorsChannel =
      EventChannel('com.meta.wearable.flutter/streamErrors');

  @override
  Future<void> initialize() async {
    await _methodChannel.invokeMethod<void>('initialize');
  }

  @override
  Future<void> startRegistration() async {
    await _methodChannel.invokeMethod<void>('startRegistration');
  }

  @override
  Future<void> startUnregistration() async {
    await _methodChannel.invokeMethod<void>('startUnregistration');
  }

  @override
  Stream<RegistrationState> get registrationState {
    return _registrationStateChannel.receiveBroadcastStream().map(
          (event) => RegistrationState.fromString(event as String),
        );
  }

  @override
  Stream<List<DeviceIdentifier>> get devices {
    return _devicesChannel.receiveBroadcastStream().map((event) {
      final list = (event as List).cast<Map>();
      return list
          .map((m) =>
              DeviceIdentifier.fromMap(Map<String, dynamic>.from(m)))
          .toList();
    });
  }

  @override
  Future<PermissionStatus> checkPermissionStatus(
      WearablePermission permission) async {
    final result = await _methodChannel.invokeMethod<String>(
      'checkPermissionStatus',
      {'permission': permission.name},
    );
    return PermissionStatus.fromString(result!);
  }

  @override
  Future<PermissionStatus> requestPermission(
      WearablePermission permission) async {
    final result = await _methodChannel.invokeMethod<String>(
      'requestPermission',
      {'permission': permission.name},
    );
    return PermissionStatus.fromString(result!);
  }

  @override
  Future<bool> handleUrl(String url) async {
    final result = await _methodChannel.invokeMethod<bool>(
      'handleUrl',
      {'url': url},
    );
    return result ?? false;
  }

  @override
  Future<Map<String, dynamic>> startStreamSession(
      StreamConfiguration configuration) async {
    final result = await _methodChannel.invokeMapMethod<String, dynamic>(
      'startStreamSession',
      configuration.toMap(),
    );
    return result!;
  }

  @override
  Future<void> stopStreamSession(String sessionId) async {
    await _methodChannel.invokeMethod<void>(
      'stopStreamSession',
      {'sessionId': sessionId},
    );
  }

  @override
  Future<PhotoData> capturePhoto(String sessionId) async {
    final result = await _methodChannel.invokeMapMethod<String, dynamic>(
      'capturePhoto',
      {'sessionId': sessionId},
    );
    return PhotoData(
      bytes: result!['bytes'] as Uint8List,
      width: result['width'] as int,
      height: result['height'] as int,
    );
  }

  @override
  Stream<StreamSessionState> get streamState {
    return _streamStateChannel.receiveBroadcastStream().map(
          (event) => StreamSessionState.fromString(event as String),
        );
  }

  @override
  Stream<VideoFrameInfo> get videoFrameInfo {
    return _videoFrameInfoChannel.receiveBroadcastStream().map((event) {
      final map = Map<String, dynamic>.from(event as Map);
      return VideoFrameInfo.fromMap(map);
    });
  }

  @override
  Stream<StreamError> get streamErrors {
    return _streamErrorsChannel.receiveBroadcastStream().map((event) {
      final map = Map<String, dynamic>.from(event as Map);
      return StreamError.fromString(map['code'] as String);
    });
  }

  // MockDeviceKit methods

  @override
  Future<String> mockPairRaybanMeta() async {
    final result = await _methodChannel.invokeMapMethod<String, dynamic>(
      'mock_pairRaybanMeta',
    );
    return result!['deviceId'] as String;
  }

  @override
  Future<void> mockUnpairDevice(String deviceId) async {
    await _methodChannel.invokeMethod<void>(
      'mock_unpairDevice',
      {'deviceId': deviceId},
    );
  }

  @override
  Future<void> mockDeviceAction(String deviceId, String action) async {
    await _methodChannel.invokeMethod<void>(
      'mock_deviceAction',
      {'deviceId': deviceId, 'action': action},
    );
  }

  @override
  Future<void> mockSetCameraFeed(String deviceId, String filePath) async {
    await _methodChannel.invokeMethod<void>(
      'mock_setCameraFeed',
      {'deviceId': deviceId, 'filePath': filePath},
    );
  }

  @override
  Future<void> mockSetCapturedImage(
      String deviceId, String filePath) async {
    await _methodChannel.invokeMethod<void>(
      'mock_setCapturedImage',
      {'deviceId': deviceId, 'filePath': filePath},
    );
  }

  @override
  Future<void> dispose() async {
    await _methodChannel.invokeMethod<void>('dispose');
  }
}
