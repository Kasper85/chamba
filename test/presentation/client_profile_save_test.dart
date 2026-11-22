import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chamba/data/models/user_account.dart';
import 'package:chamba/data/services/auth_api_service.dart';
import 'package:chamba/presentation/screens/complete_client_profile_screen.dart';
import 'package:chamba/presentation/state/app_state.dart';

class PendingProfileApi extends AuthApiService {
  final pending = Completer<UserAccount>();
  int calls = 0;
  @override
  Future<UserAccount> updateMe(
    String token, {
    String? fullName,
    String? phone,
    String? district,
    String? address,
  }) {
    calls++;
    return pending.future;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          (_) async => null,
        );
  });
  testWidgets('Editing waits for server and keeps the form on failure', (
    tester,
  ) async {
    final state = AppState();
    await state.setSession(
      const UserAccount(
        id: 'profile-test',
        fullName: 'Usuario Real',
        email: 'user@example.com',
        district: 'Pomalca',
      ),
      'test-token',
    );
    final api = PendingProfileApi();
    await tester.pumpWidget(
      MaterialApp(
        home: CompleteClientProfileScreen(appState: state, authApi: api),
      ),
    );
    expect(find.text('Editar perfil'), findsOneWidget);
    await tester.tap(find.text('Guardar perfil'));
    await tester.pump();
    expect(api.calls, 1);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    api.pending.completeError(const AuthApiException('Sin conexión'));
    await tester.pumpAndSettle();
    expect(find.text('Sin conexión'), findsOneWidget);
    expect(find.text('Usuario Real'), findsOneWidget);
    expect(find.text('Guardar perfil'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();
  });
}
