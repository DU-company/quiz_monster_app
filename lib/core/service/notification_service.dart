import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final notificationServiceProvider = Provider<NotificationService>((
  ref,
) {
  final service = FirebaseNotificationService();
  ref.onDispose(() => unawaited(service.dispose()));
  return service;
});

abstract class NotificationService {
  Future<void> initialize();
  Future<AuthorizationStatus> permission();
  Future<AuthorizationStatus> requestPermission();
  Future<String?> token();
  Stream<String> get tokens;
  Stream<RemoteMessage> get messages;
  Stream<RemoteMessage> get openedMessages;
  Future<RemoteMessage?> initialMessage();
  Future<void> dispose();
}

class FirebaseNotificationService implements NotificationService {
  static const _timeout = Duration(seconds: 10);
  FirebaseMessaging? _messaging;
  Future<void>? _initialization;
  bool _disposed = false;

  FirebaseMessaging get _client {
    final client = _messaging;
    if (_disposed || client == null) {
      throw StateError('알림 서비스가 준비되지 않았습니다.');
    }
    return client;
  }

  @override
  Future<void> initialize() {
    if (_disposed) {
      return Future.error(StateError('알림 서비스가 종료되었습니다.'));
    }
    if (_messaging != null) return Future.value();
    // 동시에 시작한 초기화는 공유하고 실패한 경우 다음 호출에서 재시도한다.
    return _initialization ??= _initialize()
        .timeout(_timeout)
        .catchError((Object error, StackTrace stack) {
          _initialization = null;
          Error.throwWithStackTrace(error, stack);
        });
  }

  Future<void> _initialize() async {
    if (kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.android &&
            defaultTargetPlatform != TargetPlatform.iOS)) {
      throw UnsupportedError('Android와 iOS에서만 알림을 지원합니다.');
    }
    await Firebase.initializeApp();
    if (_disposed) return;
    final client = FirebaseMessaging.instance;
    // 전경 알림은 앱의 SnackBar로 표시하므로 iOS 기본 표시와 중복되지 않게 한다.
    await client.setForegroundNotificationPresentationOptions(
      alert: false,
      badge: false,
      sound: false,
    );
    if (!_disposed) _messaging = client;
  }

  @override
  Future<AuthorizationStatus> permission() async {
    final settings = await _client.getNotificationSettings().timeout(
      _timeout,
    );
    return settings.authorizationStatus;
  }

  @override
  Future<AuthorizationStatus> requestPermission() async {
    final settings = await _client.requestPermission();
    return settings.authorizationStatus;
  }

  @override
  Future<String?> token() async {
    final client = _client;
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final apnsToken = await client.getAPNSToken().timeout(_timeout);
      // APNs 준비 전에는 FCM 토큰을 요청하지 않고 다음 재확인을 기다린다.
      if (apnsToken == null) return null;
    }
    if (_disposed) return null;
    return client.getToken().timeout(_timeout);
  }

  @override
  Stream<String> get tokens => _client.onTokenRefresh;

  @override
  Stream<RemoteMessage> get messages {
    _client;
    return FirebaseMessaging.onMessage;
  }

  @override
  Stream<RemoteMessage> get openedMessages {
    _client;
    return FirebaseMessaging.onMessageOpenedApp;
  }

  @override
  Future<RemoteMessage?> initialMessage() =>
      _client.getInitialMessage().timeout(_timeout);

  @override
  Future<void> dispose() async {
    _disposed = true;
    _messaging = null;
  }
}
