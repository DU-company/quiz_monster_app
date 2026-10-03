import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:quiz_monster/core/provider/selected_quiz_provider.dart';
import 'package:quiz_monster/core/utils/data_utils.dart';
import 'package:quiz_monster/data/models/quiz_model.dart';
import 'package:quiz_monster/data/models/quiz_type.dart';
import 'package:quiz_monster/ui/quiz/detail/widgets/quiz_detail_success_view.dart';
import 'package:quiz_monster/ui/quiz_settings/level/level_provider.dart';
import 'package:quiz_monster/ui/quiz_settings/player/set_player_screen.dart';
import 'package:quiz_monster/ui/quiz_settings/level/set_level_screen.dart';
import 'package:quiz_monster/ui/quiz_settings/pass/set_pass_screen.dart';
import 'package:quiz_monster/ui/quiz_settings/time/time_count_screen.dart';
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
    if (model.type == null) {
      DataUtils.showToast(msg: '앱 업데이트 후 이용할 수 있는 퀴즈입니다.');
      return;
    }
    context.pop();
    ref.read(selectedQuizProvider.notifier).state = model;
    ref.read(levelProvider.notifier).state = null;
    ref.read(currentIndexProvider.notifier).state = 0;

    if (model.type == QuizType.liar) {
      context.pushNamed(PlayerScreen.routeName);
      return;
    }
    if (model.type == QuizType.reaction) {
      context.pushNamed(TimeCountScreen.routeName);
      return;
    }
    if (model.type == QuizType.pass) {
      context.pushNamed(SetPassScreen.routeName);
      return;
    } else {
      context.pushNamed(SetLevelScreen.routeName);
      return;
    }
  }
}
