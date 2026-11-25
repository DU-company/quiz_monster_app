import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quiz_monster/core/provider/quiz_start_statistics_provider.dart';
import 'package:quiz_monster/ui/ad/interstitial_ad_view_model.dart';
import 'package:quiz_monster/ui/quiz_settings/player/set_player_view_model.dart';

final liarCountProvider = NotifierProvider(LiarCountViewModel.new);

class LiarCountViewModel extends Notifier<int> {
  bool _startConfirmed = false;

  @override
  int build() {
    ref.listen(playerViewModelProvider, (_, players) {
      if (state >= players) state = players - 1;
    });
    return 1;
  }

  void setCount(int count) {
    state = count.clamp(1, ref.read(playerViewModelProvider) - 1);
  }

  void prepareStart() => _startConfirmed = false;

  void onStart() {
    if (_startConfirmed) return;
    _startConfirmed = true;
    // 통계 API 전송
    ref
        .read(quizStartStatisticsProvider.notifier)
        .recordSelectedQuiz();
    ref.read(interstitialAdViewModelProvider.notifier).showAd();
  }
}

final liarViewModelProvider = Provider.autoDispose<Set<int>>((ref) {
  final players = ref.watch(playerViewModelProvider);
  final count = ref.watch(liarCountProvider);
  final indices = List.generate(players, (index) => index)..shuffle();
  return Set.unmodifiable(indices.take(count));
});
