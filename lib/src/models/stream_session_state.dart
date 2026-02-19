enum StreamSessionState {
  stopped,
  starting,
  waitingForDevice,
  streaming,
  paused,
  stopping;

  static StreamSessionState fromString(String value) {
    return StreamSessionState.values.firstWhere(
      (e) => e.name == value,
      orElse: () => StreamSessionState.stopped,
    );
  }
}
