class DeviceIdentifier {
  final String id;
  final String? name;

  const DeviceIdentifier({required this.id, this.name});

  factory DeviceIdentifier.fromMap(Map<String, dynamic> map) {
    return DeviceIdentifier(
      id: map['id'] as String,
      name: map['name'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {'id': id, 'name': name};
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DeviceIdentifier &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'DeviceIdentifier(id: $id, name: $name)';
}
