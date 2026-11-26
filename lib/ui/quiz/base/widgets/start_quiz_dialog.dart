import 'package:flutter/material.dart';
import 'package:quiz_monster/core/theme/theme_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:quiz_monster/ui/quiz_settings/time/set_time_view_model.dart';
import 'package:quiz_monster/core/provider/quiz_start_statistics_provider.dart';
import 'package:quiz_monster/ui/quiz_settings/player/set_player_view_model.dart';
import 'package:quiz_monster/core/provider/selected_quiz_provider.dart';
import 'package:quiz_monster/core/utils/data_utils.dart';
import 'package:quiz_monster/data/models/quiz_model.dart';
import 'package:quiz_monster/data/entities/quiz_entity.dart';
import 'package:quiz_monster/ui/quiz/detail/widgets/quiz_detail_success_view.dart';
import 'package:quiz_monster/ui/quiz_settings/level/level_provider.dart';
import 'package:quiz_monster/ui/quiz_settings/player/set_player_screen.dart';
import 'package:quiz_monster/ui/quiz_settings/level/set_level_screen.dart';
import 'package:quiz_monster/ui/quiz_settings/pass/set_pass_screen.dart';
import 'package:quiz_monster/ui/quiz_settings/time/time_count_screen.dart';
import 'package:quiz_monster/ui/common/widgets/dialog/base_confirm_dialog.dart';

class StartQuizDialog extends ConsumerStatefulWidget {
  final QuizModel model;

  const StartQuizDialog({super.key, required this.model});

  @override
  ConsumerState<StartQuizDialog> createState() =>
      _StartQuizDialogState();
}

class _StartQuizDialogState extends ConsumerState<StartQuizDialog> {
  bool _confirmed = false;
  QuizModel get model => widget.model;

  @override
  Widget build(BuildContext context) {
    return BaseConfirmDialog(
      title: model.title,
      contentWidget: model.desc.trim().isEmpty
          ? null
          : _QuizDescription(model.desc),
      confirmLabel: '시작하기',
      onTapConfirm: () => onTapStart(context, ref),
      cancelLabel: '닫기',
    );
  }

  void onTapStart(BuildContext context, WidgetRef ref) {
    if (_confirmed) return;
    if (model.type == null) {
      DataUtils.showToast(msg: '앱 업데이트 후 이용할 수 있는 퀴즈입니다.');
      return;
    }
    _confirmed = true;
    context.pop();
    ref.read(selectedQuizProvider.notifier).state = model;
    ref.read(levelProvider.notifier).state = null;
    ref.read(currentIndexProvider.notifier).state = 0;

    if (model.type == QuizType.liar) {
      ref.read(playerViewModelProvider.notifier).prepareStart();
      context.pushNamed(PlayerScreen.routeName);
      return;
    }
    if (model.type == QuizType.reaction) {
      // 통계 API 전송
      ref
          .read(quizStartStatisticsProvider.notifier)
          .recordSelectedQuiz();
      context.pushNamed(TimeCountScreen.routeName);
      return;
    }
    ref.read(timeViewModelProvider.notifier).prepareStart();
    if (model.type == QuizType.pass) {
      context.pushNamed(SetPassScreen.routeName);
      return;
    } else {
      context.pushNamed(SetLevelScreen.routeName);
      return;
    }
  }
}

class _QuizDescription extends ConsumerWidget {
  final String description;
  const _QuizDescription(this.description);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(themeServiceProvider);
    final lines = description.trim().split('\n');
    final bodyStyle = theme.typo.body2.copyWith(
      color: theme.color.secondary,
      fontSize: 16,
      height: 1.25,
      fontWeight: FontWeight.normal,
    );
    final bulletStyle = bodyStyle.copyWith(height: 1.35);
    final items = <Widget>[];
    var previousWasBullet = false;
    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;
      final isCondition =
          items.isEmpty && RegExp(r'^\([^()]+\)$').hasMatch(line);
      final bullet = RegExp(r'^[-•]\s+').firstMatch(line);
      if (items.isNotEmpty) {
        items.add(
          SizedBox(
            height: previousWasBullet && bullet != null ? 4 : 2,
          ),
        );
      }
      previousWasBullet = bullet != null;
      if (isCondition) {
        items.add(
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 5,
            ),
            decoration: const ShapeDecoration(
              color: Colors.black,
              shape: StadiumBorder(),
            ),
            child: Text(
              line.substring(1, line.length - 1),
              style: bodyStyle.copyWith(
                color: Colors.white,
                fontSize: 14,
                fontWeight: theme.typo.semiBold,
              ),
            ),
          ),
        );
      } else if (bullet != null) {
        items.add(
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('•', style: bulletStyle),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  line.substring(bullet.end),
                  style: bulletStyle,
                ),
              ),
            ],
          ),
        );
      } else {
        items.add(Text(line, style: bodyStyle));
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items,
    );
  }
}
