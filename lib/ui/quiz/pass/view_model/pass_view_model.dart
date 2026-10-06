import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:quiz_monster/ui/ad/rewarded_ad_provider.dart';
import 'package:quiz_monster/ui/quiz/detail/widgets/quiz_detail_success_view.dart';
import 'package:quiz_monster/ui/quiz/pass/view_model/pass_state.dart';
import 'package:quiz_monster/ui/quiz_settings/time/set_time_screen.dart';

final passViewModelProvider = NotifierProvider(() => PassViewModel());

class PassViewModel extends Notifier<PassState> {
  final _resolvedIndices = <int>{};
  @override
  PassState build() {
    state = PassState();
    return state;
  }

  void onPassChanged(int number) {
    state = state.copyWith(passCount: number);
  }

  void setItemCount(int itemCount) {
    state = state.copyWith(itemCount: itemCount);
  }

  /// 패스를 사용하지 않겠다
  void onTapNoPass(BuildContext context) {
    state = state.copyWith(passCount: 0);
    onTapNext(context);
  }

  /// Setting 화면에서 다음 버튼을 눌렀을 때
  void onTapNext(BuildContext context) {
    context.pushNamed(SetTimeScreen.routeName);

    /// 결과 화면을 위한 pass/correct 상태값 초기화
    _resolvedIndices.clear();
    state = state.copyWith(
      correctWords: [],
      passedWords: [],
      advancing: false,
    );
  }

  Future<void> onTapPass(
    PageController pageController,
    String word,
  ) => _answer(pageController, word, passed: true);

  Future<void> onTapCorrect(
    PageController pageController,
    String word,
  ) => _answer(pageController, word, passed: false);

  Future<void> _answer(
    PageController controller,
    String word, {
    required bool passed,
  }) async {
    final index = ref.read(currentIndexProvider);
    if (state.advancing ||
        index < 0 ||
        index >= state.itemCount ||
        _resolvedIndices.contains(index) ||
        passed && state.passCount <= 0 ||
        !controller.hasClients ||
        !controller.position.hasViewportDimension) {
      return;
    }
    final page = controller.page;
    if (page == null || (page - index).abs() > 0.001) return;

    // 문항 번호로 한 번만 집계하며 NEXT/PASS가 같은 문항을 중복 처리하지 못하게 한다.
    _resolvedIndices.add(index);
    state = state.copyWith(
      advancing: true,
      passCount: passed ? state.passCount - 1 : state.passCount,
      passedWords: passed ? [...state.passedWords, word] : null,
      correctWords: passed ? null : [...state.correctWords, word],
    );
    try {
      await controller.animateToPage(
        index + 1,
        duration: const Duration(milliseconds: 300),
        curve: Curves.linear,
      );
    } finally {
      if (ref.mounted) state = state.copyWith(advancing: false);
    }
  }

  /// 한 잔 마시고 패스 추가
  void addPassByDrinking() async {
    state = state.copyWith(
      passCount: state.passCount + 1,
      didDrink: true,
    );
  }

  /// 광고 보고 패스 추가되는 로직
  void showAd() {
    ref
        .read(rewardedAdViewModelProvider.notifier)
        .showAd(
          onRewarded: () =>
              state = state.copyWith(passCount: state.passCount + 1),
        );
  }

  void reset() {
    _resolvedIndices.clear();
    state = PassState();
    ref.read(currentIndexProvider.notifier).state = 0;
  }
}
