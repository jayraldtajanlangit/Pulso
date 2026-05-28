import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';

typedef PickedImage = ({Uint8List bytes, String mimeType});

abstract class ImagePickerService {
  Future<PickedImage?> pickImage();
  Future<List<PickedImage>> pickMultipleImages();
}

class DefaultImagePickerService implements ImagePickerService {
  DefaultImagePickerService([ImagePicker? picker])
    : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  @override
  Future<PickedImage?> pickImage() async {
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1080,
      maxHeight: 1080,
      imageQuality: 85,
    );
    if (file == null) return null;
    final bytes = await file.readAsBytes();
    final ext = file.name.split('.').last.toLowerCase();
    final mime = ext == 'png' ? 'image/png' : 'image/jpeg';
    return (bytes: bytes, mimeType: mime);
  }

  @override
  Future<List<PickedImage>> pickMultipleImages() async {
    final files = await _picker.pickMultiImage(
      maxWidth: 1080,
      maxHeight: 1080,
      imageQuality: 85,
    );
    final results = <PickedImage>[];
    for (final file in files) {
      final bytes = await file.readAsBytes();
      final ext = file.name.split('.').last.toLowerCase();
      final mime = ext == 'png' ? 'image/png' : 'image/jpeg';
      results.add((bytes: bytes, mimeType: mime));
    }
    return results;
  }
}
