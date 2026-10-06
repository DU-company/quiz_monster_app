import 'package:firebase_messaging/firebase_messaging.dart';

enum NotificationSync {
  idle,
  pending,
  synced,
  unavailable,
  failed,
  authFailed,
  conflict,
  tokenConflict,
}

class NotificationState {
  final bool ready;
  final bool enabled;
  final bool busy;
  final AuthorizationStatus permission;
  final NotificationSync sync;
  final RemoteMessage? foregroundMessage;

  const NotificationState({
    this.ready = false,
    this.enabled = false,
    this.busy = false,
    this.permission = AuthorizationStatus.notDetermined,
    this.sync = NotificationSync.idle,
    this.foregroundMessage,
  });

  bool get permitted =>
      permission == AuthorizationStatus.authorized ||
      permission == AuthorizationStatus.provisional;

  bool get switchValue => enabled && permitted;

  String get description {
    if (!ready) return busy ? '알림 설정을 확인하고 있어요.' : '알림 기능을 준비하고 있어요.';
    if (sync == NotificationSync.authFailed) {
      return '알림 등록 정보를 확인하지 못했어요. 개발자에게 문의해 주세요.';
    }
    if (sync == NotificationSync.conflict) {
      return '다른 알림 설정이 먼저 반영됐어요. 알림을 다시 선택해 주세요.';
    }
    if (sync == NotificationSync.tokenConflict) {
      return '알림 등록을 완료하지 못했어요. 다시 등록해 주세요.';
    }
    if (busy) return '알림 설정을 저장하고 있어요.';
    if (sync == NotificationSync.failed) {
      return '설정을 반영하지 못했어요. 다시 시도해 주세요.';
    }
    if (sync == NotificationSync.unavailable) {
      return '알림 서비스 연결을 준비하고 있어요.';
    }
    if (sync == NotificationSync.pending) {
      return '설정을 반영하는 중이에요. 연결 후 다시 확인해 주세요.';
    }
    if (enabled && !permitted) return '기기 설정에서 퀴즈몬스터의 알림을 허용해 주세요.';
    return switchValue ? '알림을 받을 수 있어요.' : '알림을 받지 않아요.';
  }

  NotificationState copyWith({
    bool? ready,
    bool? enabled,
    bool? busy,
    AuthorizationStatus? permission,
    NotificationSync? sync,
    RemoteMessage? foregroundMessage,
  }) {
    return NotificationState(
      ready: ready ?? this.ready,
      enabled: enabled ?? this.enabled,
      busy: busy ?? this.busy,
      permission: permission ?? this.permission,
      sync: sync ?? this.sync,
      foregroundMessage: foregroundMessage ?? this.foregroundMessage,
    );
  }
}
