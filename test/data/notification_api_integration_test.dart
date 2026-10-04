import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:quiz_monster/core/service/notification_installation_store.dart';
import 'package:quiz_monster/data/models/notification_installation.dart';
import 'package:quiz_monster/data/data_sources/notification_data_source.dart';
import 'package:quiz_monster/data/repositories/notification_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _MemoryStore implements NotificationInstallationStore {
  NotificationInstallation? value;
  @override
  Future<NotificationInstallation?> read() async => value;
  @override
  Future<void> write(NotificationInstallation installation) async =>
      value = installation;
}

void main() {
  final url = Platform.environment['NOTIFICATION_TEST_URL'];
  final key = Platform.environment['NOTIFICATION_TEST_ANON_KEY'];
  test(
    'local API registers, rotates, disables and rejects stale/foreign requests',
    () async {
      SharedPreferences.setMockInitialValues({});
      final client = SupabaseClient(url!, key!);
      addTearDown(client.dispose);
      final source = SupabaseNotificationDataSource(client);
      final store = _MemoryStore();
      final repository = NotificationRepository(source, store);
      final token =
          'integration-${DateTime.now().microsecondsSinceEpoch}';
      await repository.synchronize(
        enabled: true,
        permissionStatus: 'authorized',
        token: token,
      );
      expect(store.value!.acknowledged, isTrue);
      final first = store.value!;
      await repository.synchronize(
        enabled: true,
        permissionStatus: 'authorized',
        token: '$token-new',
      );
      expect(store.value!.revision, greaterThan(first.revision));
      await repository.saveEnabled(false);
      final restarted = NotificationRepository(source, store);
      await restarted.synchronize(
        enabled: false,
        permissionStatus: 'authorized',
        token: '$token-new',
      );
      expect(store.value!.acknowledged, isTrue);
      expect((await source.register(store.value!)).enabled, isFalse);
      await expectLater(
        source.synchronize(first),
        throwsA(
          isA<FunctionException>().having(
            (e) => e.status,
            'status',
            409,
          ),
        ),
      );
      final wrong = NotificationInstallation(
        id: first.id,
        secret: '0' * 64,
        revision: first.revision,
        payload: first.payload,
      );
      await expectLater(
        source.register(wrong),
        throwsA(
          isA<FunctionException>().having(
            (e) => e.status,
            'status',
            401,
          ),
        ),
      );
      await expectLater(
        client.from('push_tokens').select(),
        throwsA(isA<PostgrestException>()),
      );
    },
    skip: url == null || key == null
        ? '격리 로컬 API 환경변수가 없으면 실행하지 않습니다.'
        : false,
  );
}
