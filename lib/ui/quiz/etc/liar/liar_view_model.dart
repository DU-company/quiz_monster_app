import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quiz_monster/ui/quiz_settings/player/set_player_view_model.dart';

/// 라이어가 몇 번째 index인지 정하는 viewModel
final liarViewModelProvider = NotifierProvider.autoDispose(
  () => LiarViewModel(),
);

class LiarViewModel extends Notifier<int> {
  @override
  int build() {
    return setLiar();
  }

  int setLiar() {
    final players = ref.read(playerViewModelProvider);
    final Random random = Random();
    final liarIndex = random.nextInt(players);
    state = liarIndex;
    return liarIndex;
  }
}
