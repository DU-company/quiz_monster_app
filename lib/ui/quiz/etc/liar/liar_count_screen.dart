import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quiz_monster/ui/common/widgets/primary_button.dart';
import 'package:quiz_monster/ui/quiz_settings/player/set_player_view_model.dart';
import 'package:quiz_monster/ui/common/layout/setting_layout.dart';
import 'package:quiz_monster/ui/quiz_settings/player/widgets/count_selector.dart';
import 'package:quiz_monster/ui/quiz/etc/liar/liar_view_model.dart';
import 'package:go_router/go_router.dart';
import 'package:quiz_monster/ui/ad/ad_finished_provider.dart';
import 'package:quiz_monster/ui/ad/interstitial_ad_view_model.dart';
import 'package:quiz_monster/ui/quiz_settings/time/time_count_screen.dart';

class LiarCountScreen extends ConsumerWidget {
  static const routeName = 'liar-count';
  const LiarCountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(adFinishedProvider, (p, n) {
      if (n == true) {
        context.goNamed(TimeCountScreen.routeName);
        ref.read(adFinishedProvider.notifier).onReset();
      }
    });
    ref.watch(interstitialAdViewModelProvider);
    final count = ref.watch(liarCountProvider);
    final maximum = ref.watch(playerViewModelProvider) - 1;
    final viewModel = ref.read(liarCountProvider.notifier);
    return SettingLayout(
      label: '라이어 수를\n선택해 주세요',
      body: CountSelector(
        count: count,
        minimum: 1,
        maximum: maximum,
        onTapDecrease: () => viewModel.setCount(count - 1),
        onTapIncrease: () => viewModel.setCount(count + 1),
      ),
      footer: PrimaryButton(
        label: '게임 시작',
        onPressed: viewModel.onStart,
      ),
    );
  }
}
