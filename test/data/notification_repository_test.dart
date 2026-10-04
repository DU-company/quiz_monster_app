import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:quiz_monster/core/exception/notification_exception.dart';
import 'package:quiz_monster/core/service/notification_installation_store.dart';
import 'package:quiz_monster/data/data_sources/notification_data_source.dart';
import 'package:quiz_monster/data/entities/notification_sync_entity.dart';
import 'package:quiz_monster/data/models/notification_installation.dart';
import 'package:quiz_monster/data/repositories/notification_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MemoryStore implements NotificationInstallationStore {
  NotificationInstallation? value;
  bool failWrites = false;

  @override
  Future<NotificationInstallation?> read() async => value;

  @override
  Future<void> write(NotificationInstallation installation) async {
    if (failWrites) throw StateError('storage unavailable');
    value = NotificationInstallation.decode(installation.encode());
  }
}

class FakeDataSource implements NotificationDataSource {
  final registrations = <NotificationInstallation>[];
  final requests = <NotificationInstallation>[];
  Future<NotificationSyncEntity> Function(NotificationInstallation)?
  onRegister;
  Future<NotificationSyncEntity> Function(NotificationInstallation)?
  onSync;

  @override
  Future<NotificationSyncEntity> register(
    NotificationInstallation value,
  ) async {
    registrations.add(value);
    return onRegister != null
        ? onRegister!(value)
        : const NotificationSyncEntity(revision: 0, enabled: false);
  }

  @override
  Future<NotificationSyncEntity> synchronize(
    NotificationInstallation value,
  ) async {
    requests.add(value);
    return onSync != null
        ? onSync!(value)
        : NotificationSyncEntity(
            revision: value.revision,
            enabled: value.payload.shouldReceive,
          );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late MemoryStore store;
  late FakeDataSource source;
  late NotificationRepository repository;

  Future<void> sync({
    bool enabled = true,
    String token = 'token-a',
  }) => repository.synchronize(
    enabled: enabled,
    permissionStatus: 'authorized',
    token: token,
  );

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    store = MemoryStore();
    source = FakeDataSource();
    repository = NotificationRepository(source, store);
  });

  test(
    'persists installation credentials and pending payload before registration',
    () async {
      source.onRegister = (sent) async {
        expect(store.value!.id, sent.id);
        expect(store.value!.secret, sent.secret);
        expect(store.value!.payload.token, 'token-a');
        expect(store.value!.acknowledged, isFalse);
        expect(sent.id, matches(RegExp(r'^[a-f0-9-]{36}$')));
        expect(sent.secret, matches(RegExp(r'^[a-f0-9]{64}$')));
        return const NotificationSyncEntity(
          revision: 0,
          enabled: false,
        );
      };
      await sync();
      expect(store.value!.acknowledged, isTrue);
    },
  );

  test(
    'recreated repository retries a failed request with identical credentials and revision',
    () async {
      source.onSync = (_) async =>
          throw StateError('network unavailable');
      await expectLater(
        sync(),
        throwsA(isA<NotificationException>()),
      );
      final first = source.requests.single;
      expect(store.value!.acknowledged, isFalse);
      repository = NotificationRepository(source, store);
      source.onSync = null;
      await sync();
      final retry = source.requests.last;
      expect(retry.id, first.id);
      expect(retry.secret, first.secret);
      expect(retry.revision, first.revision);
      expect(retry.payload.matches(first.payload), isTrue);
      expect(store.value!.acknowledged, isTrue);
    },
  );

  test(
    'late ON acknowledgement preserves a newer persisted OFF request',
    () async {
      final started = Completer<void>();
      final response = Completer<NotificationSyncEntity>();
      source.onSync = (_) {
        started.complete();
        return response.future;
      };
      final pending = sync();
      await started.future;
      final onRevision = source.requests.single.revision;
      await repository.saveEnabled(false);
      expect(await repository.enabled(), isFalse);
      expect(store.value!.revision, greaterThan(onRevision));
      response.complete(
        NotificationSyncEntity(revision: onRevision, enabled: true),
      );
      await pending;
      expect(store.value!.payload.enabled, isFalse);
      expect(store.value!.acknowledged, isFalse);
      source.onSync = null;
      await sync(enabled: false);
      expect(source.requests.last.payload.shouldReceive, isFalse);
      expect(store.value!.acknowledged, isTrue);
    },
  );

  test(
    'identical payload retains revision while token or selection changes increment it',
    () async {
      await sync();
      final initial = store.value!.revision;
      await sync();
      expect(store.value!.revision, initial);
      await sync(token: 'token-b');
      expect(store.value!.revision, initial + 1);
      await sync(enabled: false, token: 'token-b');
      expect(store.value!.revision, initial + 2);
    },
  );

  test(
    'server conflict records revision and next explicit selection exceeds it',
    () async {
      source.onRegister = (_) async =>
          const NotificationSyncEntity(revision: 8, enabled: false);
      await expectLater(
        sync(),
        throwsA(isA<NotificationConflictException>()),
      );
      expect(source.requests, isEmpty);
      expect(store.value!.observedRevision, 8);
      expect(store.value!.revision, 1);
      await sync(enabled: false);
      expect(source.requests.single.revision, 9);
      expect(store.value!.acknowledged, isTrue);
    },
  );

  for (final entry in <(int, String?, Matcher)>[
    (401, null, isA<NotificationAuthException>()),
    (
      409,
      'token_conflict',
      isA<NotificationTokenConflictException>(),
    ),
    (409, 'revision_conflict', isA<NotificationConflictException>()),
    (404, null, isA<NotificationSetupException>()),
  ]) {
    test('classifies server error ${entry.$1} ${entry.$2}', () async {
      source.onSync = (_) async => throw FunctionException(
        status: entry.$1,
        details: {'error': entry.$2},
      );
      await expectLater(sync(), throwsA(entry.$3));
      expect(store.value!.acknowledged, isFalse);
    });
  }

  test(
    'failed durable write prevents registration and synchronization',
    () async {
      store.failWrites = true;
      await expectLater(
        sync(),
        throwsA(isA<NotificationException>()),
      );
      expect(source.registrations, isEmpty);
      expect(source.requests, isEmpty);
    },
  );

  test(
    'secure payload serialization preserves pending state and observed revision',
    () {
      final original = NotificationInstallation.create()
          .prepare(
            const NotificationPayload(
              enabled: true,
              permissionStatus: 'provisional',
              token: 'token-a',
            ),
          )
          .recordServer(17);
      final restored = NotificationInstallation.decode(
        original.encode(),
      );
      expect(restored.id, original.id);
      expect(restored.secret, original.secret);
      expect(restored.revision, original.revision);
      expect(restored.observedRevision, 17);
      expect(restored.payload.matches(original.payload), isTrue);
      expect(restored.acknowledged, isFalse);
      final acknowledged = restored.recordServer(
        17,
        acknowledged: true,
      );
      expect(
        NotificationInstallation.decode(
          acknowledged.encode(),
        ).acknowledged,
        isTrue,
      );
    },
  );
}
