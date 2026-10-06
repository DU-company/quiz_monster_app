import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:quiz_monster/data/models/notification_installation.dart';

final notificationInstallationStoreProvider =
    Provider<NotificationInstallationStore>(
      (ref) => SecureNotificationInstallationStore(),
    );

abstract class NotificationInstallationStore {
  Future<NotificationInstallation?> read();
  Future<void> write(NotificationInstallation installation);
}

class SecureNotificationInstallationStore
    implements NotificationInstallationStore {
  static const _key = 'notification_installation_v1';
  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
      sharedPreferencesName: 'quiz_notification_secure',
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  @override
  Future<NotificationInstallation?> read() async {
    final value = await _storage.read(key: _key);
    return value == null
        ? null
        : NotificationInstallation.decode(value);
  }

  @override
  Future<void> write(NotificationInstallation installation) =>
      _storage.write(key: _key, value: installation.encode());
}
