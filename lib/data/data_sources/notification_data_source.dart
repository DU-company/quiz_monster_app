import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quiz_monster/core/exception/notification_exception.dart';

final notificationDataSourceProvider =
    Provider<NotificationDataSource>(
      (ref) => UnconfiguredNotificationDataSource(),
    );

abstract class NotificationDataSource {
  Future<void> synchronize({required bool enabled, String? token});
}

class UnconfiguredNotificationDataSource
    implements NotificationDataSource {
  @override
  Future<void> synchronize({
    required bool enabled,
    String? token,
  }) async {
    throw NotificationSetupException();
  }
}
