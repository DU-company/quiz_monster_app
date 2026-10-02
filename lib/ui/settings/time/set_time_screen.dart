import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:go_router/go_router.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:quiz_monster/ui/ad/ad_count_provider.dart';
import 'package:quiz_monster/ui/ad/ad_finished_provider.dart';
import 'package:quiz_monster/ui/ad/interstitial_ad_view_model.dart';
import 'package:quiz_monster/ui/common/widgets/primary_button.dart';
import 'package:quiz_monster/core/provider/selected_quiz_provider.dart';
import 'package:quiz_monster/data/models/quiz_type.dart';
import 'package:quiz_monster/core/theme/responsive/layout.dart';
import 'package:quiz_monster/core/utils/data_utils.dart';
import 'package:quiz_monster/ui/common/layout/setting_layout.dart';
import 'package:quiz_monster/ui/settings/time/set_time_view_model.dart';
import 'package:quiz_monster/ui/settings/time/time_count_screen.dart';
import 'package:quiz_monster/ui/settings/time/widgets/time_picker.dart';

class SetTimeScreen extends ConsumerWidget {
  static String routeName = 'time';

  const SetTimeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(adFinishedProvider, (p, n) {
      if (n == true) {
        context.goNamed(TimeCountScreen.routeName);
        ref.read(adFinishedProvider.notifier).onReset();
      }
    });
    final selectedQuiz = ref.watch(selectedQuizProvider);
    final isPassQuiz = selectedQuiz?.type == QuizType.pass;
    final timeState = ref.watch(timeViewModelProvider);
    final viewModel = ref.read(timeViewModelProvider.notifier);
    return SettingLayout(
      label: isPassQuiz ? '총 게임 시간을\n설정해 주세요' : '1인 제한 시간을\n설정해 주세요',
      body: TimePicker(
        newDuration: timeState,
        onTimerDurationChanged: viewModel.onTimeChanged,
      ),
      footer: PrimaryButton(
        label: 'START',
        onPressed: () => viewModel.onTapStart(),
      ),
    );
  }
}
