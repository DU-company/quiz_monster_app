import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:quiz_monster/ui/common/layout/default_layout.dart';
import 'package:quiz_monster/ui/common/widgets/dialog/base_confirm_dialog.dart';
import 'package:quiz_monster/ui/common/widgets/primary_button.dart';
import 'package:quiz_monster/ui/quiz/base/quiz_screen.dart';
import 'package:quiz_monster/ui/quiz/etc/liar/liar_screen.dart';
import 'package:quiz_monster/ui/quiz/pass/pass_result_screen.dart';
import 'package:quiz_monster/ui/quiz/pass/view_model/pass_view_model.dart';

void main() {
  for (final result in [false, true]) {
    testWidgets('${result ? "결과" : "라이어"} 화면의 뒤로가기는 확인 후 홈으로 이동한다', (
      tester,
    ) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final router = GoRouter(
        initialLocation: '/game',
        routes: [
          GoRoute(
            path: '/',
            name: QuizScreen.routeName,
            builder: (_, _) => const Scaffold(body: Text('테스트 홈')),
          ),
          GoRoute(
            path: '/game',
            builder: (_, _) => result
                ? const ResultScreen()
                : const DefaultLayout(
                    child: LiarGameScreen(title: '라이어', items: []),
                  ),
          ),
        ],
      );
      addTearDown(router.dispose);
      container.read(passViewModelProvider.notifier).onPassChanged(1);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(BaseConfirmDialog), findsOneWidget);
      expect(
        tester
            .widget<BaseConfirmDialog>(find.byType(BaseConfirmDialog))
            .title,
        result ? '홈으로' : '게임 종료',
      );
      // 확인 창에서 뒤로가기는 창만 닫고 게임/결과를 유지한다.
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('테스트 홈'), findsNothing);
      expect(find.byType(BaseConfirmDialog), findsNothing);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.tap(find.text(result ? '취소' : '게임 계속하기'));
      await tester.pumpAndSettle();
      expect(find.text('테스트 홈'), findsNothing);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(PrimaryButton, result ? '홈으로' : '종료하기'),
      );
      await tester.pumpAndSettle();
      expect(find.text('테스트 홈'), findsOneWidget);
      if (result) {
        expect(container.read(passViewModelProvider).passCount, 3);
      }
    });
  }
}
