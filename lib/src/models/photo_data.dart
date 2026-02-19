import 'dart:typed_data';

class PhotoData {
  final Uint8List bytes;
  final int width;
  final int height;

  const PhotoData({
    required this.bytes,
    required this.width,
    required this.height,
  });

  factory PhotoData.fromMap(Map<String, dynamic> map) {
    return PhotoData(
      bytes: map['bytes'] as Uint8List,
      width: map['width'] as int,
      height: map['height'] as int,
    );
  }

  @override
  String toString() =>
      'PhotoData(width: $width, height: $height, bytes: ${bytes.length} bytes)';
}
