import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quiz_monster/ui/common/widgets/primary_button.dart';
import 'package:quiz_monster/ui/quiz_settings/player/set_player_view_model.dart';
import 'package:quiz_monster/ui/common/layout/setting_layout.dart';
import 'package:quiz_monster/ui/quiz_settings/player/widgets/count_selector.dart';

class PlayerScreen extends ConsumerWidget {
  static String routeName = 'player';
  final VoidCallback onNext;
  const PlayerScreen({super.key, required this.onNext});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final players = ref.watch(playerViewModelProvider);
    final viewModel = ref.read(playerViewModelProvider.notifier);

    return SettingLayout(
      label: '참가자 수를\n선택해 주세요',
      body: CountSelector(
        onTapDecrease: () => viewModel.decreasePlayer(),
        onTapIncrease: () => viewModel.increasePlayer(),
        count: players,
        minimum: PlayerViewModel.minimumPlayers,
        maximum: 30,
      ),
      footer: PrimaryButton(label: '다음', onPressed: onNext),
    );
  }
}
