import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quiz_monster/core/service/supabase_provider.dart';
import 'package:quiz_monster/data/entities/notification_sync_entity.dart';
import 'package:quiz_monster/data/models/notification_installation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final notificationDataSourceProvider =
    Provider<NotificationDataSource>(
      (ref) =>
          SupabaseNotificationDataSource(ref.read(supabaseProvider)),
    );

abstract class NotificationDataSource {
  Future<NotificationSyncEntity> register(
    NotificationInstallation installation,
  );
  Future<NotificationSyncEntity> synchronize(
    NotificationInstallation installation,
  );
}

class SupabaseNotificationDataSource
    implements NotificationDataSource {
  final SupabaseClient client;
  SupabaseNotificationDataSource(this.client);

  @override
  Future<NotificationSyncEntity> register(
    NotificationInstallation installation,
  ) => _invoke('register', installation);

  @override
  Future<NotificationSyncEntity> synchronize(
    NotificationInstallation installation,
  ) => _invoke('sync', installation);

  Future<NotificationSyncEntity> _invoke(
    String action,
    NotificationInstallation installation,
  ) async {
    final response = await client.functions.invoke(
      'notification-installations',
      headers: {'X-Installation-Secret': installation.secret},
      body: {
        'action': action,
        'installation_id': installation.id,
        if (action == 'sync') ...{
          'revision': installation.revision,
          'enabled': installation.payload.shouldReceive,
          'fcm_token': installation.payload.token,
        },
      },
    );
    return NotificationSyncEntity.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }
}
