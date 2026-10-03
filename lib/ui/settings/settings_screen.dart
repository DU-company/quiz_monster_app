import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:quiz_monster/core/theme/theme_provider.dart';
import 'package:quiz_monster/ui/common/layout/default_layout.dart';
import 'package:quiz_monster/ui/quiz/base/quiz_screen.dart';
import 'package:quiz_monster/ui/settings/settings_view_model.dart';

class SettingsScreen extends ConsumerWidget {
  static const routeName = 'settings';

  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(themeServiceProvider);
    final version = ref.watch(appVersionProvider);

    return DefaultLayout(
      appBar: AppBar(
        backgroundColor: theme.color.surface,
        foregroundColor: theme.color.text,
        title: Text('환경설정', style: theme.typo.headline6),
        leading: IconButton(
          tooltip: '뒤로',
          icon: const Icon(Icons.arrow_back),
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
          SwitchListTile(
            title: Text('알림 허용', style: theme.typo.subtitle1),
            subtitle: Text(
              '알림 기능을 준비하고 있어요.',
              style: theme.typo.body1,
            ),
            value: false,
            onChanged: null,
          ),
          ListTile(
            title: Text('앱 버전', style: theme.typo.subtitle1),
            subtitle: version.when(
              data: (value) => Text(value, style: theme.typo.body1),
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
          ListTile(
            title: Text('개발자 이메일', style: theme.typo.subtitle1),
            subtitle: Text(developerEmail, style: theme.typo.body1),
            trailing: IconButton(
              tooltip: '이메일 복사',
              icon: const Icon(Icons.copy_outlined),
              onPressed: () => _copyEmail(context),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _copyEmail(BuildContext context) async {
    try {
      await Clipboard.setData(
        const ClipboardData(text: developerEmail),
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('이메일을 복사했어요.')));
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('이메일을 복사하지 못했어요. 다시 시도해 주세요.')),
      );
    }
  }
}
