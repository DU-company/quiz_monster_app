import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:quiz_monster/ui/ad/rewarded_ad_provider.dart';
import 'package:quiz_monster/ui/quiz/detail/widgets/quiz_detail_success_view.dart';
import 'package:quiz_monster/ui/quiz/pass/view_model/pass_state.dart';
import 'package:quiz_monster/ui/quiz_settings/time/set_time_screen.dart';

final passViewModelProvider = NotifierProvider(() => PassViewModel());

class PassViewModel extends Notifier<PassState> {
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
    state = state.copyWith(correctWords: [], passedWords: []);
  }

  /// 패스 사용했을 때
  void onTapPass(PageController pageController, String word) {
    pageController.nextPage(
      duration: Duration(milliseconds: 300),
      curve: Curves.linear,
    );
    state = state.copyWith(
      passCount: state.passCount - 1,
      passedWords: [...state.passedWords, word],
    );
    ref
        .read(currentIndexProvider.notifier)
        .update((state) => state + 1);
  }

  /// 문제를 맞추고 다음 버튼을 눌렀을 때
  void onTapCorrect(PageController pageController, String word) {
    pageController.nextPage(
      duration: Duration(milliseconds: 300),
      curve: Curves.linear,
    );
    state = state.copyWith(
      correctWords: [...state.correctWords, word],
    );
    ref
        .read(currentIndexProvider.notifier)
        .update((state) => state + 1);
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
    state = PassState();
    ref.read(currentIndexProvider.notifier).state = 0;
  }
}
