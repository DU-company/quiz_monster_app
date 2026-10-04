class NotificationSyncEntity {
  final int revision;
  final bool enabled;

  const NotificationSyncEntity({
    required this.revision,
    required this.enabled,
  });

  factory NotificationSyncEntity.fromJson(Map<String, dynamic> json) {
    final revision = json['revision'];
    if (revision is! int ||
        revision < 0 ||
        json['enabled'] is! bool) {
      throw const FormatException('Invalid notification response');
    }
    return NotificationSyncEntity(
      revision: revision,
      enabled: json['enabled'] as bool,
    );
  }
}
