import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:quiz_monster/data/models/quiz_detail_model.dart';
import 'package:quiz_monster/data/models/quiz_group.dart';
import 'package:quiz_monster/data/models/quiz_model.dart';
import 'package:quiz_monster/data/models/quiz_type.dart';
import 'package:quiz_monster/ui/ad/rewarded_ad_provider.dart';
import 'package:quiz_monster/ui/quiz/detail/widgets/quiz_detail_success_view.dart';
import 'package:quiz_monster/ui/quiz/etc/liar/widgets/liar_body.dart';
import 'package:quiz_monster/ui/quiz/no_pass/no_pass_quiz_screen.dart';
import 'package:quiz_monster/ui/quiz/pass/pass_quiz_screen.dart';
import 'package:quiz_monster/ui/quiz/pass/view_model/pass_view_model.dart';

class _NoAdViewModel extends RewardedAdViewModel {
  @override
  FutureOr<RewardedAd?> build() => null;
}

const _passQuiz = QuizModel(
  id: 21,
  title: '몸으로 말해요',
  subTitle: '',
  desc: '',
  type: QuizType.pass,
  group: QuizGroup.charades,
);

List<QuizDetailModel> _passItems(int count) => [
  for (var index = 0; index < count; index++)
    PassQuizDetailModel(
      quiz: _passQuiz,
      id: '$index',
      level: 1,
      answer: '단어 $index',
    ),
];

Widget _screen(ProviderContainer container, Widget child) =>
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: Scaffold(body: Column(children: [child])),
      ),
    );

void main() {
  testWidgets('패스 화면은 받은 문항이 2개면 두 번째 뒤에서 종료한다', (tester) async {
    final container = ProviderContainer(
      overrides: [
        rewardedAdViewModelProvider.overrideWith(_NoAdViewModel.new),
      ],
    );
    final controller = PageController();
    addTearDown(container.dispose);
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      _screen(
        container,
        PassQuizScreen(
          items: _passItems(2),
          pageController: controller,
          remainingSeconds: 60,
        ),
      ),
    );
    await tester.pump();
    expect(container.read(passViewModelProvider).itemCount, 2);

    await tester.tap(find.text('NEXT ▶'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('NEXT ▶'));
    await tester.pumpAndSettle();

    expect(find.text('💣 GAME OVER 💣'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('패스 화면은 빈 문항과 범위 밖 인덱스를 안전하게 종료한다', (tester) async {
    final container = ProviderContainer(
      overrides: [
        rewardedAdViewModelProvider.overrideWith(_NoAdViewModel.new),
      ],
    );
    final controller = PageController();
    addTearDown(container.dispose);
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      _screen(
        container,
        PassQuizScreen(
          items: const [],
          pageController: controller,
          remainingSeconds: 60,
        ),
      ),
    );
    await tester.pump();
    expect(find.text('💣 GAME OVER 💣'), findsOneWidget);

    container.read(currentIndexProvider.notifier).state = 31;
    await tester.pumpWidget(
      _screen(
        container,
        PassQuizScreen(
          items: _passItems(31),
          pageController: controller,
          remainingSeconds: 60,
        ),
      ),
    );
    await tester.pump();
    expect(container.read(passViewModelProvider).itemCount, 30);
    expect(find.text('💣 GAME OVER 💣'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('일반 퀴즈는 빈 문항과 범위 밖 인덱스를 안내한다', (tester) async {
    final container = ProviderContainer();
    final controller = PageController();
    addTearDown(container.dispose);
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      _screen(
        container,
        NoPassQuizScreen(
          items: const [],
          pageController: controller,
          remainingSeconds: 60,
          onNextPressed: () {},
          onPrevPressed: () {},
          showAnswerPressed: () {},
        ),
      ),
    );
    expect(find.text('표시할 문제가 없습니다.'), findsOneWidget);

    container.read(currentIndexProvider.notifier).state = 5;
    await tester.pump();
    expect(find.text('표시할 문제가 없습니다.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('라이어 화면은 빈 문항에서 첫 항목을 읽지 않는다', (tester) async {
    final container = ProviderContainer();
    final controller = PageController();
    addTearDown(container.dispose);
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      _screen(
        container,
        LiarBody(
          items: const [],
          pageController: controller,
          playerCount: 3,
          showAnswer: false,
          currentIndex: 0,
          liarIndex: 1,
          isLastPage: false,
          onTapButton: () {},
        ),
      ),
    );

    expect(find.text('표시할 문제가 없습니다.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
