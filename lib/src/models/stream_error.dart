enum StreamError {
  internalError,
  deviceNotFound,
  deviceNotConnected,
  timeout,
  videoStreamingError,
  audioStreamingError,
  permissionDenied,
  hingesClosed,
  unknown;

  static StreamError fromString(String value) {
    return StreamError.values.firstWhere(
      (e) => e.name == value,
      orElse: () => StreamError.unknown,
    );
  }
}

class MetaWearablesException implements Exception {
  final String code;
  final String message;
  final dynamic details;

  const MetaWearablesException({
    required this.code,
    required this.message,
    this.details,
  });

  @override
  String toString() =>
      'MetaWearablesException(code: $code, message: $message, details: $details)';
}
