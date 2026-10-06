import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:permission_handler/permission_handler.dart'
    as permissions;
import 'package:flutter/material.dart';
import 'package:quiz_monster/ui/settings/notification_view_model.dart';
import 'package:quiz_monster/ui/settings/notification_state.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:quiz_monster/core/theme/theme_provider.dart';
import 'package:quiz_monster/core/utils/data_utils.dart';
import 'package:quiz_monster/ui/common/layout/default_layout.dart';
import 'package:quiz_monster/ui/common/widgets/dialog/base_confirm_dialog.dart';
import 'package:quiz_monster/ui/quiz/base/quiz_screen.dart';
import 'package:quiz_monster/ui/settings/settings_view_model.dart';

class SettingsScreen extends ConsumerWidget {
  static const routeName = 'settings';

  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(themeServiceProvider);
    final version = ref.watch(appVersionProvider);
    final notifications = ref.watch(notificationViewModelProvider);

    ref.listen(notificationViewModelProvider, (previous, next) {
      // 처리 완료 후 문제가 생긴 경우에만 안내해 중간 상태 토스트를 막는다.
      if (next.busy ||
          !(ModalRoute.of(context)?.isCurrent ?? false)) {
        return;
      }
      final needsNotice =
          next.sync != NotificationSync.idle &&
          next.sync != NotificationSync.synced;
      if (needsNotice &&
          (previous?.busy == true ||
              previous?.sync != next.sync ||
              previous?.permission != next.permission)) {
        DataUtils.showToast(msg: next.description);
      }
    });

    return DefaultLayout(
      backgroundColor: theme.color.onPrimary,
      appBar: AppBar(
        backgroundColor: theme.color.onPrimary,
        surfaceTintColor: Colors.transparent,
        foregroundColor: theme.color.secondary,
        title: Text(
          '환경설정',
          style: theme.typo.headline6.copyWith(
            color: theme.color.secondary,
          ),
        ),
        leading: BackButton(
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.goNamed(QuizScreen.routeName);
            }
          },
        ),
      ),
      child: ListView(
        children: [
          ListTile(
            title: Text(
              '알림 허용',
              style: theme.typo.subtitle1.copyWith(
                color: theme.color.secondary,
              ),
            ),
            trailing: Switch.adaptive(
              activeTrackColor: theme.color.primary,
              value: notifications.switchValue,
              onChanged:
                  notifications.ready &&
                      (!notifications.busy ||
                          notifications.switchValue)
                  ? (enabled) =>
                        _setNotifications(context, ref, enabled)
                  : null,
            ),
          ),
          if (!notifications.busy &&
              (notifications.sync == NotificationSync.failed ||
                  notifications.sync == NotificationSync.pending))
            TextButton(
              onPressed: () => ref
                  .read(notificationViewModelProvider.notifier)
                  .refresh(),
              child: const Text('알림 설정 다시 확인'),
            ),
          if (!notifications.busy &&
              notifications.sync == NotificationSync.tokenConflict)
            TextButton(
              onPressed: () => ref
                  .read(notificationViewModelProvider.notifier)
                  .renewToken(),
              child: const Text('알림 등록 다시 시도'),
            ),
          ListTile(
            title: Text(
              '문의사항',
              style: theme.typo.subtitle1.copyWith(
                color: theme.color.secondary,
              ),
            ),
            subtitle: Text(
              developerEmail,
              style: theme.typo.body1.copyWith(
                color: theme.color.subtext,
              ),
            ),
            onTap: () => _copyEmail(context),
          ),
          ListTile(
            title: Text(
              '앱 버전',
              style: theme.typo.subtitle1.copyWith(
                color: theme.color.secondary,
              ),
            ),
            subtitle: version.when(
              data: (value) => Text(
                value,
                style: theme.typo.body1.copyWith(
                  color: theme.color.subtext,
                ),
              ),
              loading: () => const Text('확인 중...'),
              error: (_, _) => const Text('버전 정보를 불러오지 못했어요.'),
            ),
            trailing: version.hasError
                ? IconButton(
                    tooltip: '버전 다시 확인',
                    icon: const Icon(Icons.refresh),
                    onPressed: () =>
                        ref.invalidate(appVersionProvider),
                  )
                : null,
          ),
        ],
      ),
    );
  }

  Future<void> _setNotifications(
    BuildContext context,
    WidgetRef ref,
    bool enabled,
  ) async {
    final notifier = ref.read(notificationViewModelProvider.notifier);
    final permission = ref
        .read(notificationViewModelProvider)
        .permission;
    if (!enabled || permission != AuthorizationStatus.denied) {
      await notifier.setEnabled(enabled);
      if (!context.mounted ||
          !enabled ||
          ref.read(notificationViewModelProvider).permission !=
              AuthorizationStatus.denied) {
        return;
      }
    }

    if (!context.mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => BaseConfirmDialog(
        title: '알림 권한이 필요해요',
        content: '기기 설정에서 퀴즈몬스터의 알림을 허용해 주세요.\n앱 설정으로 이동할까요?',
        confirmLabel: '설정 열기',
        onTapConfirm: () => Navigator.of(dialogContext).pop(true),
        cancelLabel: '취소',
        onTapCancel: () => Navigator.of(dialogContext).pop(false),
      ),
    );
    if (confirmed != true || !context.mounted) return;
    // 복귀 시 권한을 다시 확인할 수 있도록 앱의 알림 수신 선택도 저장한다.
    await notifier.setEnabled(true);
    if (!context.mounted) return;
    try {
      final opened = await permissions.openAppSettings();
      if (!opened && context.mounted) {
        DataUtils.showToast(
          msg: '앱 설정을 열지 못했어요. 기기 설정에서 직접 변경해 주세요.',
        );
      }
    } catch (_) {
      if (context.mounted) {
        DataUtils.showToast(
          msg: '앱 설정을 열지 못했어요. 기기 설정에서 직접 변경해 주세요.',
        );
      }
    }
  }

  Future<void> _copyEmail(BuildContext context) async {
    try {
      await Clipboard.setData(
        const ClipboardData(text: developerEmail),
      );
      if (!context.mounted) return;
      DataUtils.showToast(msg: '이메일을 복사했어요.');
    } catch (_) {
      if (!context.mounted) return;
      DataUtils.showToast(msg: '이메일을 복사하지 못했어요. 다시 시도해 주세요.');
    }
  }
}
