enum WearablePermission {
  camera;

  static WearablePermission fromString(String value) {
    return WearablePermission.values.firstWhere(
      (e) => e.name == value,
      orElse: () => WearablePermission.camera,
    );
  }
}

enum PermissionStatus {
  granted,
  denied;

  static PermissionStatus fromString(String value) {
    return PermissionStatus.values.firstWhere(
      (e) => e.name == value,
      orElse: () => PermissionStatus.denied,
    );
  }
}
