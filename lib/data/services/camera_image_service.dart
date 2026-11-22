import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

class CameraPermissionException implements Exception {
  final bool blocked;
  const CameraPermissionException(this.blocked);
}

class CameraImageService {
  static const channel = MethodChannel('chamba/camera_permissions');
  final Future<XFile?> Function(ImageSource)? picker;
  CameraImageService({this.picker});
  static Future<void> openSettings() => channel.invokeMethod('settings');
  Future<XFile?> pick(ImageSource source) async {
    if (source == ImageSource.camera &&
        !kIsWeb &&
        defaultTargetPlatform == TargetPlatform.android) {
      final permission = await channel.invokeMethod<String>('request');
      if (permission != 'granted') {
        throw CameraPermissionException(permission == 'blocked');
      }
    }
    return picker != null
        ? picker!(source)
        : ImagePicker().pickImage(
            source: source,
            maxWidth: 900,
            maxHeight: 900,
            imageQuality: 65,
          );
  }
}
