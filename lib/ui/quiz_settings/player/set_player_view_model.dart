import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:quiz_monster/core/provider/selected_quiz_provider.dart';
import 'package:quiz_monster/ui/ad/ad_count_provider.dart';
import 'package:quiz_monster/ui/ad/interstitial_ad_view_model.dart';
import 'package:quiz_monster/core/utils/data_utils.dart';
import 'package:quiz_monster/ui/quiz/etc/liar/liar_screen.dart';
import 'package:quiz_monster/ui/quiz_settings/time/time_count_screen.dart';

final playerViewModelProvider = NotifierProvider(
  () => PlayerViewModel(),
);

class PlayerViewModel extends Notifier<int> {
  @override
  int build() {
    state = 3;
    return state;
  }

  void increasePlayer() async {
    state = state + 1;
  }

  void decreasePlayer() {
    state = state - 1;
  }

  void onStart(BuildContext context) {
    ref.read(interstitialAdViewModelProvider.notifier).showAd();
  }
}
