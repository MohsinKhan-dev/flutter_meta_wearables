enum DeviceCompatibility {
  compatible,
  deviceUpdateRequired,
  appUpdateRequired,
  unknown;

  static DeviceCompatibility fromString(String value) {
    return DeviceCompatibility.values.firstWhere(
      (e) => e.name == value,
      orElse: () => DeviceCompatibility.unknown,
    );
  }
}
