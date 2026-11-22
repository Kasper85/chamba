import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:chamba/data/services/voice_message_service.dart';
import 'package:chamba/data/services/camera_image_service.dart';
import 'package:chamba/data/services/chat_api_service.dart';
import 'package:chamba/data/services/api_client.dart';
import 'package:chamba/data/models/user_account.dart';
import 'package:chamba/presentation/state/app_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(CameraImageService.channel, null),
  );
  for (final permission in ['denied', 'blocked']) {
    test('microphone $permission cannot start recording', () async {
      final calls = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(CameraImageService.channel, (call) async {
            calls.add(call.method);
            return permission;
          });
      await expectLater(
        VoiceMessageService().start(),
        throwsA(
          isA<MicrophonePermissionException>().having(
            (e) => e.blocked,
            'blocked',
            permission == 'blocked',
          ),
        ),
      );
      expect(calls, ['requestMicrophone']);
    });
  }
  test('microphone granted records and returns bytes', () async {
    final calls = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(CameraImageService.channel, (call) async {
          calls.add(call.method);
          if (call.method == 'requestMicrophone') return 'granted';
          if (call.method == 'stopAudioRecording') {
            return Uint8List.fromList([255, 241, 1, 2, 3, 4, 5]);
          }
          return null;
        });
    final service = VoiceMessageService();
    await service.start();
    expect(await service.stop(), hasLength(7));
    expect(calls, ['requestMicrophone', 'startAudio', 'stopAudioRecording']);
  });
  test('one person keeps identity and empty fields across both roles', () {
    final state = AppState();
    state.currentUser = const UserAccount(
      id: 'one-person',
      fullName: 'Nombre Real',
      email: 'persona@example.com',
    );
    state.switchRole(UserRole.worker);
    expect(state.currentWorkerProfile.name, 'Nombre Real');
    expect(state.currentWorkerProfile.phone, '');
    expect(state.currentUser!.workerProfile, isNull);
    state.switchRole(UserRole.client);
    expect(state.currentUser!.id, 'one-person');
    expect(state.clientPhone, '');
    expect(state.clientAddress, '');
    expect(state.clientDistrict, '');
    state.dispose();
  });
  test('voice retry transmits same id and audio content', () async {
    final payloads = <Map>[];
    final api = ChatApiService(
      apiClient: ApiClient(
        baseUrl: 'http://example.test',
        httpClient: MockClient((request) async {
          payloads.add(jsonDecode(request.body) as Map);
          return http.Response('{}', 201);
        }),
      ),
    );
    for (var i = 0; i < 2; i++) {
      await api.send(
        'job',
        'token',
        'same-voice-id',
        'Mensaje de voz',
        audioBase64: '//EBAgMEBQ==',
        audioDurationSeconds: 2,
      );
    }
    expect(payloads[0], payloads[1]);
    expect(payloads[0]['audioDurationSeconds'], 2);
  });
}
