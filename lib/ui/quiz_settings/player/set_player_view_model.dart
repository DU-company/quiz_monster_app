import 'package:flutter_riverpod/flutter_riverpod.dart';

final playerViewModelProvider = NotifierProvider(
  () => PlayerViewModel(),
);

class PlayerViewModel extends Notifier<int> {
  static const minimumPlayers = 3;

  @override
  int build() {
    return minimumPlayers;
  }

  void increasePlayer() {
    if (state < 30) state++;
  }

  void decreasePlayer() {
    if (state <= minimumPlayers) return;
    state--;
  }
}
