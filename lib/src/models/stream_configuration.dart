enum VideoQuality {
  low,
  medium,
  high;

  static VideoQuality fromString(String value) {
    return VideoQuality.values.firstWhere(
      (e) => e.name == value,
      orElse: () => VideoQuality.medium,
    );
  }
}

class StreamConfiguration {
  final VideoQuality videoQuality;
  final int frameRate;

  const StreamConfiguration({
    this.videoQuality = VideoQuality.medium,
    this.frameRate = 24,
  });

  Map<String, dynamic> toMap() {
    return {
      'videoQuality': videoQuality.name,
      'frameRate': frameRate,
    };
  }
}
