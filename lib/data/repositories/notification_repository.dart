import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quiz_monster/core/exception/notification_exception.dart';
import 'package:quiz_monster/data/data_sources/notification_data_source.dart';
import 'package:shared_preferences/shared_preferences.dart';

final notificationRepositoryProvider = Provider((ref) {
  return NotificationRepository(
    ref.read(notificationDataSourceProvider),
  );
});

class NotificationRepository {
  final NotificationDataSource dataSource;

  NotificationRepository(this.dataSource);

  Future<bool> enabled() async {
    return _read('notifications_enabled', true);
  }

  Future<bool> permissionRequested() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('notifications_permission_requested') ??
        false;
  }

  Future<bool> _read(String key, bool fallback) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(key) ?? fallback;
    } catch (_) {
      throw NotificationException();
    }
  }

  Future<void> saveEnabled(bool enabled) =>
      _save('notifications_enabled', enabled);

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

  Future<void> synchronize({
    required bool enabled,
    String? token,
  }) async {
    try {
      await dataSource
          .synchronize(enabled: enabled, token: token)
          .timeout(const Duration(seconds: 10));
    } on NotificationSetupException {
      rethrow;
    } catch (_) {
      throw NotificationException();
    }
  }
}
