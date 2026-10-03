import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quiz_monster/ui/settings/notification_view_model.dart';

class NotificationListener extends ConsumerStatefulWidget {
  final Widget child;
  final GlobalKey<ScaffoldMessengerState> messengerKey;

  const NotificationListener({
    super.key,
    required this.child,
    required this.messengerKey,
  });

  @override
  ConsumerState<NotificationListener> createState() =>
      _NotificationListenerState();
}

class _NotificationListenerState
    extends ConsumerState<NotificationListener>
    with WidgetsBindingObserver {
  bool _started = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // 첫 화면이 표시된 뒤 알림 초기화와 권한 요청을 시작한다.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _start();
    });
  }

  void _start() {
    if (_started) return;
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    if (lifecycle != null && lifecycle != AppLifecycleState.resumed) {
      return;
    }
    _started = true;
    unawaited(
      ref.read(notificationViewModelProvider.notifier).start(),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    if (!_started) {
      _start();
    } else {
      // 기기 설정에서 바뀐 권한과 놓친 토큰 갱신을 앱 복귀 시 확인한다.
      unawaited(
        ref.read(notificationViewModelProvider.notifier).refresh(),
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(
      notificationViewModelProvider.select(
        (state) => state.foregroundMessage,
      ),
      (_, message) {
        if (message == null ||
            WidgetsBinding.instance.lifecycleState !=
                AppLifecycleState.resumed) {
          return;
        }
        final notification = message.notification;
        final content = [notification?.title, notification?.body]
            .whereType<String>()
            .where((text) => text.trim().isNotEmpty)
            .join('\n');
        if (content.isEmpty) return;
        widget.messengerKey.currentState?.showSnackBar(
          SnackBar(content: Text(content)),
        );
      },
    );
    return widget.child;
  }
}
