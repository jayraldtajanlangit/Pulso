import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';

typedef PickedImage = ({Uint8List bytes, String mimeType});

abstract class ImagePickerService {
  Future<PickedImage?> pickImage();
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
}
