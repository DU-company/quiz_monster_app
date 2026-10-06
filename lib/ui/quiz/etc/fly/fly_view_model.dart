import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quiz_monster/ui/quiz/etc/fly/fly_state.dart';
import 'package:quiz_monster/ui/quiz_settings/level/level_provider.dart';

final flyViewModelProvider = NotifierProvider(() => FlyViewModel());

class FlyViewModel extends Notifier<FlyState> {
  @override
  FlyState build() {
    state = FlyState(flyCount: 0, flyPositions: []);
    return state;
  }

  final Random _random = Random();

  void initFlies(BuildContext context) {
    final level = ref.read(levelProvider);
    if (level == null) {
      // 5~24마리 사이 랜덤 개수
      state = state.copyWith(flyCount: _random.nextInt(18) + 6);
    } else if (level == 1) {
      // 6~12마리 사이 랜덤 개수
      state = state.copyWith(flyCount: _random.nextInt(6) + 6);
    } else if (level == 2) {
      // 8~16마리 사이 랜덤 개수
      state = state.copyWith(flyCount: _random.nextInt(8) + 8);
    } else if (level == 3) {
      // 12~24마리 사이 랜덤 개수
      state = state.copyWith(flyCount: _random.nextInt(12) + 12);
    }

    final width = MediaQuery.of(context).size.width / 1.5;
    final height = MediaQuery.of(context).size.height / 2;

    final positions = List.generate(
      state.flyCount,
      (index) => Offset(
        _random.nextDouble() * width, // X 좌표 (화면 크기에 맞게 조정)
        _random.nextDouble() * height, // Y 좌표
      ),
    );

    state = state.copyWith(flyPositions: positions);
  }
}
