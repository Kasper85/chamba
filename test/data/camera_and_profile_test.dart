import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:chamba/data/services/camera_image_service.dart';
import 'package:chamba/data/models/user_account.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(CameraImageService.channel, null);
  });
  for (final status in ['denied', 'blocked']) {
    test('camera $status never launches picker', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      var launches = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(CameraImageService.channel, (_) async => status);
      final service = CameraImageService(picker: (_) async { launches++; return null; });
      await expectLater(service.pick(ImageSource.camera), throwsA(isA<CameraPermissionException>().having((e) => e.blocked, 'blocked', status == 'blocked')));
      expect(launches, 0);
    });
  }
  test('camera granted launches picker only on demand', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    var launches = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(CameraImageService.channel, (_) async => 'granted');
    final service = CameraImageService(picker: (_) async { launches++; return null; });
    expect(launches, 0);
    await service.pick(ImageSource.camera);
    expect(launches, 1);
  });
  test('gallery uses system picker without camera permission', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(CameraImageService.channel, (_) async => throw StateError('Unexpected permission request'));
    await CameraImageService(picker: (_) async => null).pick(ImageSource.gallery);
  });
  test('profile fields survive session serialization', () {
    const profile = WorkerProfileData(id: 'worker', dni: '12345678', baseRate: 70, serviceRadiusKm: 10, experienceYears: 0, skills: ['Electricidad'], portfolio: [{'id': 'project', 'title': 'Trabajo real'}]);
    final restored = WorkerProfileData.fromJson(profile.toJson());
    expect(restored.dni, profile.dni);
    expect(restored.baseRate, 70);
    expect(restored.serviceRadiusKm, 10);
    expect(restored.experienceYears, 0);
    expect(restored.skills, profile.skills);
    expect(restored.portfolio, profile.portfolio);
  });
}
