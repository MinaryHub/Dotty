import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';

import '../dot_matrix/dot_bitmap.dart';

/// Thrown when the picked file is not an image the platform can decode.
class UnsupportedImageException implements Exception {}

/// Lets the user pick an image file and returns it normalized for storage,
/// or null if the picker was cancelled.
Future<Uint8List?> pickImage() async {
  const images = XTypeGroup(
    label: '이미지',
    extensions: ['png', 'jpg', 'jpeg', 'gif', 'webp', 'bmp'],
    mimeTypes: [
      'image/png',
      'image/jpeg',
      'image/gif',
      'image/webp',
      'image/bmp',
    ],
    uniformTypeIdentifiers: ['public.image'],
    webWildCards: ['image/*'],
  );
  final file = await openFile(acceptedTypeGroups: [images]);
  if (file == null) return null;
  final normalized = await normalizeImportedImage(await file.readAsBytes());
  if (normalized == null) throw UnsupportedImageException();
  return normalized;
}
