import 'dart:typed_data';

import 'camera_image_service.dart';

class MicrophonePermissionException implements Exception {
  final bool blocked;
  const MicrophonePermissionException(this.blocked);
}

class VoiceMessageService {
  Future<void> start() async {
    final status = await CameraImageService.channel.invokeMethod<String>(
      'requestMicrophone',
    );
    if (status != 'granted') {
      throw MicrophonePermissionException(status == 'blocked');
    }
    await CameraImageService.channel.invokeMethod<void>('startAudio');
  }

  Future<Uint8List> stop() async {
    final bytes = await CameraImageService.channel.invokeMethod<Uint8List>(
      'stopAudioRecording',
    );
    if (bytes == null || bytes.length < 7) throw StateError('Audio vacío');
    return bytes;
  }

  Future<void> cancel() =>
      CameraImageService.channel.invokeMethod<void>('cancelAudio');
  Future<void> play(Uint8List bytes) => CameraImageService.channel
      .invokeMethod<void>('playAudio', {'bytes': bytes});
  Future<void> stopPlayback() =>
      CameraImageService.channel.invokeMethod<void>('stopAudioPlayback');
}
