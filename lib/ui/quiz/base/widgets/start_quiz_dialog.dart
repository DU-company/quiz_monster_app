import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:quiz_monster/core/provider/selected_quiz_provider.dart';
import 'package:quiz_monster/data/models/quiz_model.dart';
import 'package:quiz_monster/ui/settings/player/set_player_screen.dart';
import 'package:quiz_monster/ui/settings/level/set_level_screen.dart';
import 'package:quiz_monster/ui/settings/pass/set_pass_screen.dart';
import 'package:quiz_monster/ui/settings/time/time_count_screen.dart';
import 'package:quiz_monster/ui/common/widgets/dialog/base_confirm_dialog.dart';

class StartQuizDialog extends ConsumerWidget {
  final QuizModel model;

  const StartQuizDialog({super.key, required this.model});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return BaseConfirmDialog(
      title: model.title,
      content: model.desc,
      confirmLabel: '시작하기',
      onTapConfirm: () => onTapStart(context, ref),
      cancelLabel: '닫기',
    );
  }

  void onTapStart(BuildContext context, WidgetRef ref) {
    context.pop();
    ref.read(selectedQuizProvider.notifier).state = model;

    if (model.title.contains('라이어 게임')) {
      context.pushNamed(PlayerScreen.routeName);
      return;
    }
    if (model.title == '반응속도 테스트') {
      context.pushNamed(TimeCountScreen.routeName);
      return;
    }
    if (model.hasPass) {
      context.pushNamed(SetPassScreen.routeName);
      return;
    } else {
      context.pushNamed(SetLevelScreen.routeName);
      return;
    }
  }
}
