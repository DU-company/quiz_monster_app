import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:quiz_monster/data/models/pagination_state.dart';
import 'package:quiz_monster/ui/ad/banner_ad_view_model.dart';
import 'package:quiz_monster/ui/common/widgets/loading_widget.dart';
import 'package:quiz_monster/ui/quiz/base/quiz_screen.dart';
import 'package:quiz_monster/ui/quiz/base/quiz_view_model.dart';

class _RetryQuizViewModel extends QuizViewModel {
  int retries = 0;

  @override
  PaginationState build() =>
      PaginationError(message: '목록을 불러오지 못했어요.');

  @override
  Future<void> getQuizList() async {
    retries++;
    state = PaginationLoading();
  }
}

class _NoBannerAd extends BannerAdViewModel {
  @override
  BannerAd? build() => null;
}

void main() {
  testWidgets('퀴즈 홈의 목록 오류에서 다시 시도하면 로딩 화면으로 전환한다', (tester) async {
    final viewModel = _RetryQuizViewModel();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          quizViewModelProvider.overrideWith(() => viewModel),
          bannerAdViewModelProvider.overrideWith(_NoBannerAd.new),
        ],
        child: const MaterialApp(home: QuizScreen()),
      ),
    );

    expect(find.text('목록을 불러오지 못했어요.'), findsOneWidget);
    await tester.tap(find.text('다시시도'));
    await tester.pump();

    expect(viewModel.retries, 1);
    expect(find.byType(LoadingWidget), findsOneWidget);
    expect(find.text('목록을 불러오지 못했어요.'), findsNothing);
  });
}
