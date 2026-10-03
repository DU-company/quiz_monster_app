import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quiz_monster/ui/quiz/etc/reaction/view_model/recation_state.dart';

final reactionViewModelProvider = NotifierProvider.autoDispose(
  () => ReactionViewModel(),
);

class ReactionViewModel extends Notifier<ReactionState> {
  Timer? _waitingTimer;

  @override
  ReactionState build() {
    ref.onDispose(() => _waitingTimer?.cancel());
    state = ReactionState();
    _countRandomTime();
    return state;
  }

  void _countRandomTime() {
    _waitingTimer?.cancel();
    _waitingTimer = Timer(
      Duration(milliseconds: _setRandomTime()),
      () {
        state = state.copyWith(
          startTime: DateTime.now().millisecondsSinceEpoch,
          isGreen: true,
        );
      },
    );
  }

  // 2~4초 사이의 랜덤 시간 설정
  int _setRandomTime() {
    return Random().nextInt(2000) + 2000;
  }

  void onTapCircle() {
    if (state.isGreen && state.result.isNotEmpty) return;
    // if (isGreen && label.isNotEmpty) return;
    if (state.startTime != null) {
      int reactionTime =
          DateTime.now().millisecondsSinceEpoch - state.startTime!;
      // 50ms만큼 임의의 상향조정
      int result = reactionTime >= 51
          ? reactionTime - 50
          : reactionTime;

      state = state.copyWith(
        startTime: null,
        result: '$result ms',
        resultList: [...state.resultList, result],
      );
    } else {
      _waitingTimer?.cancel();
      state = state.copyWith(
        startTime: null,
        isGreen: true,
        currentStep: 0,
        result: '너무 빨리 눌렀습니다!',
        resultList: [],
      );
    }
  }

  void onTapNext() {
    state = state.copyWith(
      startTime: null,
      isGreen: false,
      result: '',
      currentStep: state.currentStep + 1,
    );
    _countRandomTime();
  }

  void resetScreen() {
    state = state.copyWith(
      startTime: null,
      isGreen: false,
      currentStep: 1,
      result: '',
      resultList: [],
    );
    _countRandomTime();
  }
}
