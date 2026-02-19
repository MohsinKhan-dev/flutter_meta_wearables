class VideoFrameInfo {
  final int width;
  final int height;
  final int timestampMs;

  const VideoFrameInfo({
    required this.width,
    required this.height,
    required this.timestampMs,
  });

  factory VideoFrameInfo.fromMap(Map<String, dynamic> map) {
    return VideoFrameInfo(
      width: map['width'] as int,
      height: map['height'] as int,
      timestampMs: map['timestampMs'] as int,
    );
  }

  double get aspectRatio => height > 0 ? width / height : 16 / 9;

  @override
  String toString() =>
      'VideoFrameInfo(width: $width, height: $height, timestampMs: $timestampMs)';
}
