import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:quiz_monster/core/provider/selected_quiz_provider.dart';
import 'package:quiz_monster/ui/quiz_settings/time/set_time_view_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final detailTimerViewModelProvider = NotifierProvider.autoDispose(
  () => DetailTimerViewModel(),
);

class DetailTimerViewModel extends Notifier<int> {
  int? timeToSec;
  Timer? _timer;

  @override
  int build() {
    ref.onDispose(() {
      stopTimer();
    });
    return restartTimer();
  }

  int restartTimer() {
    // 기존 타이머 중지
    stopTimer();
    final selectedTime = ref.read(timeViewModelProvider);
    final min = selectedTime.inMinutes.remainder(60);
    final sec = selectedTime.inSeconds.remainder(60);
    timeToSec = min * 60 + sec;

    // 시간을 초기값으로 리셋
    state = timeToSec!;
    startTimer();

    return state;
  }

  void startTimer() {
    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (state > 0) {
        state--;
      } else {
        _timer?.cancel();
      }
    });
  }

  void stopTimer() {
    _timer?.cancel();
  }
}
