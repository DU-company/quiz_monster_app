import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quiz_monster/core/exception/notification_exception.dart';
import 'package:quiz_monster/core/service/notification_installation_store.dart';
import 'package:quiz_monster/data/data_sources/notification_data_source.dart';
import 'package:quiz_monster/data/models/notification_installation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final notificationRepositoryProvider = Provider(
  (ref) => NotificationRepository(
    ref.read(notificationDataSourceProvider),
    ref.read(notificationInstallationStoreProvider),
  ),
);

class NotificationRepository {
  final NotificationDataSource dataSource;
  final NotificationInstallationStore store;
  Future<void> _storageQueue = Future.value();

  NotificationRepository(this.dataSource, this.store);

  Future<bool> enabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = await store.read();
      return stored?.payload.enabled ??
          prefs.getBool('notifications_enabled') ??
          true;
    } catch (_) {
      throw NotificationException();
    }
  }

  Future<bool> permissionRequested() async =>
      _read('notifications_permission_requested', false);

  Future<bool> _read(String key, bool fallback) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(key) ?? fallback;
    } catch (_) {
      throw NotificationException();
    }
  }

  // 선택과 요청 번호를 함께 보관해 앱이 종료돼도 이전 ON 요청보다 새 OFF를 우선한다.
  Future<void> saveEnabled(bool enabled) async {
    try {
      await _storage(() async {
        final installation = await _installation();
        final next = installation.prepare(
          NotificationPayload(
            enabled: enabled,
            permissionStatus: installation.payload.permissionStatus,
            token: installation.payload.token,
          ),
          force: true,
        );
        await store.write(next);
      });
      await _save('notifications_enabled', enabled);
    } catch (_) {
      throw NotificationException();
    }
  }

  Future<void> markPermissionRequested() =>
      _save('notifications_permission_requested', true);

  Future<void> _save(String key, bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!await prefs.setBool(key, value)) {
        throw NotificationException();
      }
    } catch (_) {
      throw NotificationException();
    }
  }

  Future<T> _storage<T>(Future<T> Function() action) {
    final result = _storageQueue.then((_) => action());
    _storageQueue = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return result;
  }

  Future<NotificationInstallation> _installation() async =>
      await store.read() ?? NotificationInstallation.create();

  Future<void> synchronize({
    required bool enabled,
    String? token,
    required String permissionStatus,
  }) async {
    try {
      final outgoing = await _storage(() async {
        final current = await _installation();
        final next = current.prepare(
          NotificationPayload(
            enabled: enabled,
            permissionStatus: permissionStatus,
            token: token,
          ),
        );
        await store.write(next);
        return next;
      });
      final registered = await dataSource
          .register(outgoing)
          .timeout(const Duration(seconds: 10));
      await _recordServer(outgoing, registered.revision);
      if (registered.revision > outgoing.revision) {
        throw NotificationConflictException();
      }
      final response = await dataSource
          .synchronize(outgoing)
          .timeout(const Duration(seconds: 10));
      if (response.revision != outgoing.revision ||
          response.enabled != outgoing.payload.shouldReceive) {
        throw NotificationConflictException();
      }
      await _recordServer(outgoing, response.revision);
    } on NotificationConflictException {
      rethrow;
    } on NotificationAuthException {
      rethrow;
    } on FunctionException catch (error) {
      final details = error.details;
      final code = details is Map ? details['error'] : null;
      if (error.status == 401) throw NotificationAuthException();
      if (code == 'token_conflict') {
        throw NotificationTokenConflictException();
      }
      if (error.status == 409) throw NotificationConflictException();
      if (error.status == 404) throw NotificationSetupException();
      throw NotificationException();
    } catch (_) {
      throw NotificationException();
    }
  }

  // 늦게 도착한 응답도 서버 번호만 기록하고 최신 로컬 선택·요청 번호는 보존한다.
  Future<void> _recordServer(
    NotificationInstallation sent,
    int revision,
  ) => _storage(() async {
    final current = await store.read();
    if (current == null || current.id != sent.id) return;
    await store.write(current.recordServer(revision));
  });
}
