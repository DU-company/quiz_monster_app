import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:go_router/go_router.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:quiz_monster/core/theme/theme_provider.dart';
import 'package:quiz_monster/ui/ad/ad_finished_provider.dart';
import 'package:quiz_monster/ui/common/widgets/primary_button.dart';
import 'package:quiz_monster/core/utils/data_utils.dart';
import 'package:quiz_monster/ui/quiz_settings/player/set_player_view_model.dart';
import 'package:quiz_monster/ui/quiz/etc/liar/liar_screen.dart';
import 'package:quiz_monster/ui/common/layout/setting_layout.dart';
import 'package:quiz_monster/ui/quiz_settings/time/time_count_screen.dart';

import '../../ad/ad_count_provider.dart';
import '../../ad/interstitial_ad_view_model.dart';

class PlayerScreen extends ConsumerWidget {
  static String routeName = 'player';
  const PlayerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(adFinishedProvider, (p, n) {
      if (n == true) {
        context.goNamed(TimeCountScreen.routeName);
        ref.read(adFinishedProvider.notifier).onReset();
      }
    });
    ref.watch(interstitialAdViewModelProvider);
    ref.watch(adCountProvider);
    final players = ref.watch(playerViewModelProvider);
    final viewModel = ref.read(playerViewModelProvider.notifier);

    return SettingLayout(
      label: '참가자 수를\n선택해 주세요',
      body: _Body(
        onTapDecrease: () => viewModel.decreasePlayer(),
        onTapIncrease: () => viewModel.increasePlayer(),
        players: players,
      ),
      footer: PrimaryButton(
        label: '시작하기',
        onPressed: () => viewModel.onStart(context),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  final int players;
  final VoidCallback onTapIncrease;
  final VoidCallback onTapDecrease;
  const _Body({
    super.key,
    required this.players,
    required this.onTapIncrease,
    required this.onTapDecrease,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.read(themeServiceProvider);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        PrimaryButton(
          label: '−',
          onPressed: players <= 3 ? null : onTapDecrease,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0),
          child: Text('$players', style: theme.typo.headline1),
        ),
        PrimaryButton(
          label: '+',
          onPressed: players >= 30 ? null : onTapIncrease,
        ),
      ],
    );
  }
}
