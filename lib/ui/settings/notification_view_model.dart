import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quiz_monster/core/exception/notification_exception.dart';
import 'package:quiz_monster/core/service/notification_service.dart';
import 'package:quiz_monster/data/repositories/notification_repository.dart';
import 'package:quiz_monster/ui/settings/notification_state.dart';

final notificationViewModelProvider = NotifierProvider(
  NotificationViewModel.new,
);

class NotificationViewModel extends Notifier<NotificationState> {
  Future<void> _queue = Future.value();
  // 로컬 저장은 서버 응답을 기다리지 않도록 별도 순서로 처리한다.
  Future<bool> _saveQueue = Future.value(true);
  bool _preferenceDirty = false;
  bool _initialized = false;
  final _subscriptions = <StreamSubscription<dynamic>>[];
  final _messageIds = <String>{};
  String? _token;
  int _revision = 0;

  NotificationService get _service =>
      ref.read(notificationServiceProvider);
  NotificationRepository get _repository =>
      ref.read(notificationRepositoryProvider);

  @override
  NotificationState build() {
    ref.onDispose(() {
      for (final subscription in _subscriptions) {
        unawaited(subscription.cancel());
      }
    });
    return const NotificationState();
  }

  Future<void> start() =>
      _enqueue(() => _refresh(requestAtStart: true));
  Future<void> refresh() => _enqueue(() => _refresh());

  // 다른 설치와 토큰이 겹치면 사용자가 요청한 경우에만 FCM 주소를 새로 발급한다.
  Future<void> renewToken() => _enqueue(() async {
    if (!state.ready || !state.permitted) return;
    state = state.copyWith(busy: true);
    _token = await _service.renewToken();
    await _synchronize();
  });

  // 서버 작업을 순서대로 실행하고 실패가 다음 작업을 막지 않게 한다.
  Future<void> _enqueue(Future<void> Function() action) {
    _queue = _queue.then((_) async {
      if (!ref.mounted) return;
      try {
        await action();
      } catch (_) {
        if (ref.mounted) {
          state = state.copyWith(
            busy: false,
            sync: NotificationSync.failed,
          );
        }
      }
    });
    return _queue;
  }

  Future<void> _refresh({bool requestAtStart = false}) async {
    state = state.copyWith(busy: true);
    if (!_initialized) {
      final enabled = await _repository.enabled();
      try {
        await _service.initialize();
      } catch (_) {
        if (ref.mounted) {
          state = state.copyWith(
            busy: false,
            sync: NotificationSync.unavailable,
          );
        }
        return;
      }
      if (!ref.mounted) return;
      state = state.copyWith(ready: true, enabled: enabled);
      _initialized = true;
      _subscriptions.add(
        _service.tokens.listen((token) {
          _token = token;
          unawaited(_enqueue(_synchronize));
        }, onError: (_) => _streamFailed()),
      );
      _subscriptions.add(
        _service.messages.listen(
          _foreground,
          onError: (_) => _streamFailed(),
        ),
      );
      _subscriptions.add(
        _service.openedMessages.listen(
          _opened,
          onError: (_) => _streamFailed(),
        ),
      );
      final initial = await _service.initialMessage();
      if (initial != null) _opened(initial);
    }
    var permission = await _service.permission();
    // 요청 이력을 함께 확인해 앱을 다시 열 때 권한 창을 반복하지 않는다.
    if (requestAtStart &&
        state.enabled &&
        !await _repository.permissionRequested() &&
        permission != AuthorizationStatus.authorized &&
        permission != AuthorizationStatus.provisional) {
      await _repository.markPermissionRequested();
      permission = await _service.requestPermission();
    }
    if (!ref.mounted) return;
    state = state.copyWith(permission: permission);
    // 앱이 닫힌 동안 놓친 토큰 갱신도 다시 조회해 반영한다.
    _token = null;
    await _synchronize();
  }

  Future<void> setEnabled(bool enabled) {
    if (!state.ready) return Future.value();
    // 이전 비동기 응답이 최신 사용자 선택을 덮어쓰지 않도록 번호를 올린다.
    final revision = ++_revision;
    state = state.copyWith(
      enabled: enabled,
      busy: true,
      sync: NotificationSync.pending,
    );
    _preferenceDirty = true;
    // OFF 선택도 진행 중인 서버 요청을 기다리지 않고 로컬에 먼저 저장한다.
    final saved = _persistSelection();
    return _enqueue(() async {
      if (revision != _revision) return;
      if (!await saved) {
        if (ref.mounted && revision == _revision) {
          state = state.copyWith(
            busy: false,
            sync: NotificationSync.failed,
          );
        }
        return;
      }
      if (enabled) {
        var permission = await _service.permission();
        if (permission == AuthorizationStatus.notDetermined &&
            !await _repository.permissionRequested()) {
          await _repository.markPermissionRequested();
          permission = await _service.requestPermission();
        }
        if (!ref.mounted || revision != _revision) return;
        state = state.copyWith(permission: permission);
      }
      await _synchronize();
    });
  }

  Future<bool> _persistSelection() {
    final enabled = state.enabled;
    final revision = _revision;
    final repository = _repository;
    _saveQueue = _saveQueue.then((_) async {
      try {
        await repository.saveEnabled(enabled);
        if (ref.mounted && revision == _revision) {
          _preferenceDirty = false;
        }
        return true;
      } catch (_) {
        return false;
      }
    });
    return _saveQueue;
  }

  Future<void> _synchronize() async {
    if (!ref.mounted || !_initialized) return;
    final revision = _revision;
    final enabled = state.enabled && state.permitted;
    state = state.copyWith(
      busy: true,
      sync: NotificationSync.pending,
    );
    try {
      // 이전에 실패한 로컬 저장부터 재시도한 뒤 서버 상태를 반영한다.
      if (_preferenceDirty && !await _persistSelection()) {
        throw NotificationException();
      }
      if (!ref.mounted || revision != _revision) return;
      if (enabled) {
        if (_token == null) {
          final fetchedToken = await _service.token();
          // 조회 중 갱신 이벤트로 받은 새 토큰이 있다면 그 값을 유지한다.
          _token ??= fetchedToken;
        }
        if (!ref.mounted || revision != _revision) return;
        if (_token == null) {
          state = state.copyWith(
            busy: false,
            sync: NotificationSync.pending,
          );
          return;
        }
      }
      await _repository.synchronize(
        enabled: state.enabled,
        permissionStatus: state.permission.name,
        token: _token,
      );
      if (ref.mounted && revision == _revision) {
        state = state.copyWith(
          busy: false,
          sync: NotificationSync.synced,
        );
      }
    } on NotificationAuthException {
      if (ref.mounted && revision == _revision) {
        state = state.copyWith(
          busy: false,
          sync: NotificationSync.authFailed,
        );
      }
    } on NotificationTokenConflictException {
      if (ref.mounted && revision == _revision) {
        state = state.copyWith(
          busy: false,
          sync: NotificationSync.tokenConflict,
        );
      }
    } on NotificationConflictException {
      if (ref.mounted && revision == _revision) {
        state = state.copyWith(
          busy: false,
          sync: NotificationSync.conflict,
        );
      }
    } on NotificationSetupException {
      if (ref.mounted && revision == _revision) {
        state = state.copyWith(
          busy: false,
          sync: NotificationSync.unavailable,
        );
      }
    } catch (_) {
      if (ref.mounted && revision == _revision) {
        state = state.copyWith(
          busy: false,
          sync: NotificationSync.failed,
        );
      }
    }
  }

  void _streamFailed() {
    if (ref.mounted) {
      state = state.copyWith(sync: NotificationSync.failed);
    }
  }

  // 최근 메시지 ID 100개만 기억해 중복 처리를 막고 메모리 사용을 제한한다.
  bool _newMessage(RemoteMessage message) {
    final id = message.messageId;
    if (id == null) return true;
    if (!_messageIds.add(id)) return false;
    if (_messageIds.length > 100) {
      _messageIds.remove(_messageIds.first);
    }
    return true;
  }

  void _foreground(RemoteMessage message) {
    if (!ref.mounted || !state.switchValue || !_newMessage(message)) {
      return;
    }
    state = state.copyWith(foregroundMessage: message);
  }

  // 알림을 눌러도 진행 중인 게임은 유지하고 메시지 ID만 기록한다.
  void _opened(RemoteMessage message) {
    _newMessage(message);
  }
}
