import 'dart:convert';
import 'dart:math';

class NotificationPayload {
  final bool enabled;
  final String permissionStatus;
  final String? token;

  const NotificationPayload({
    required this.enabled,
    required this.permissionStatus,
    this.token,
  });

  bool get shouldReceive =>
      enabled &&
      ['authorized', 'provisional'].contains(permissionStatus);

  Map<String, dynamic> toJson() => {
    'notifications_enabled': enabled,
    'permission_status': permissionStatus,
    'fcm_token': token,
  };

  factory NotificationPayload.fromJson(Map<String, dynamic> json) =>
      NotificationPayload(
        enabled: json['notifications_enabled'] as bool,
        permissionStatus: json['permission_status'] as String,
        token: json['fcm_token'] as String?,
      );

  bool matches(NotificationPayload other) =>
      enabled == other.enabled &&
      permissionStatus == other.permissionStatus &&
      token == other.token;
}

class NotificationInstallation {
  final String id;
  final String secret;
  final int revision;
  final int observedRevision;
  final NotificationPayload payload;

  const NotificationInstallation({
    required this.id,
    required this.secret,
    required this.revision,
    this.observedRevision = 0,
    required this.payload,
  });

  factory NotificationInstallation.create() {
    final random = Random.secure();
    final id = List.generate(16, (_) => random.nextInt(256));
    id[6] = (id[6] & 15) | 64;
    id[8] = (id[8] & 63) | 128;
    String hex(List<int> bytes) =>
        bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    final value = hex(id);
    return NotificationInstallation(
      id: '${value.substring(0, 8)}-${value.substring(8, 12)}-${value.substring(12, 16)}-${value.substring(16, 20)}-${value.substring(20)}',
      secret: hex(List.generate(32, (_) => random.nextInt(256))),
      revision: 0,
      payload: const NotificationPayload(
        enabled: false,
        permissionStatus: 'notDetermined',
      ),
    );
  }

  // 새 선택에는 번호를 올리고 같은 요청의 재전송에는 기존 번호를 사용한다.
  NotificationInstallation prepare(
    NotificationPayload next, {
    bool force = false,
  }) {
    if (!force && revision > 0 && payload.matches(next)) return this;
    return NotificationInstallation(
      id: id,
      secret: secret,
      revision: max(revision, observedRevision) + 1,
      observedRevision: observedRevision,
      payload: next,
    );
  }

  NotificationInstallation recordServer(int value) =>
      NotificationInstallation(
        id: id,
        secret: secret,
        revision: revision,
        observedRevision: max(observedRevision, value),
        payload: payload,
      );

  String encode() => jsonEncode({
    'installation_id': id,
    'secret': secret,
    'revision': revision,
    'observed_revision': observedRevision,
    'payload': payload.toJson(),
  });

  factory NotificationInstallation.decode(String value) {
    final json = jsonDecode(value) as Map<String, dynamic>;
    final result = NotificationInstallation(
      id: json['installation_id'] as String,
      secret: json['secret'] as String,
      revision: json['revision'] as int,
      observedRevision: json['observed_revision'] as int? ?? 0,
      payload: NotificationPayload.fromJson(
        json['payload'] as Map<String, dynamic>,
      ),
    );
    if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(result.secret) ||
        !RegExp(
          r'^[a-f0-9]{8}-[a-f0-9]{4}-4[a-f0-9]{3}-[89ab][a-f0-9]{3}-[a-f0-9]{12}$',
        ).hasMatch(result.id) ||
        result.revision < 0 ||
        result.observedRevision < 0) {
      throw const FormatException(
        'Invalid notification installation',
      );
    }
    return result;
  }
}
