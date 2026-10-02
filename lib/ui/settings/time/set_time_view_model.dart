import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:quiz_monster/core/provider/selected_quiz_provider.dart';
import 'package:quiz_monster/data/models/quiz_type.dart';
import 'package:quiz_monster/core/utils/data_utils.dart';
import 'package:quiz_monster/ui/ad/ad_count_provider.dart';
import 'package:quiz_monster/ui/ad/interstitial_ad_view_model.dart';
import 'package:quiz_monster/ui/settings/time/time_count_screen.dart';

final timeViewModelProvider = NotifierProvider.autoDispose(
  () => TimeViewModel(),
);

class TimeViewModel extends Notifier<Duration> {
  @override
  Duration build() {
    return init();
  }

  Duration init() {
    final isPassQuiz =
        ref.read(selectedQuizProvider)?.type == QuizType.pass;
    state = isPassQuiz ? Duration(minutes: 3) : Duration(seconds: 5);
    return state;
  }

  void onTimeChanged(Duration duration) {
    state = duration;
  }

  void onTapStart() {
    if (state.inSeconds < 3) {
      DataUtils.showToast(msg: '최소 제한 시간은 3초 입니다.');
    } else {
      ref.read(interstitialAdViewModelProvider.notifier).showAd();
    }
  }
}
