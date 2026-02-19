import 'meta_wearables_platform.dart';
import 'models/models.dart';

class MetaWearablesStreamSession {
  final String _sessionId;
  final int textureId;
  final MetaWearablesPlatform _platform;

  MetaWearablesStreamSession({
    required String sessionId,
    required this.textureId,
    required MetaWearablesPlatform platform,
  })  : _sessionId = sessionId,
        _platform = platform;

  Stream<StreamSessionState> get state => _platform.streamState;

  Stream<VideoFrameInfo> get videoFrameInfo => _platform.videoFrameInfo;

  Stream<StreamError> get errors => _platform.streamErrors;

  Future<PhotoData> capturePhoto() => _platform.capturePhoto(_sessionId);

  Future<void> stop() => _platform.stopStreamSession(_sessionId);
}
