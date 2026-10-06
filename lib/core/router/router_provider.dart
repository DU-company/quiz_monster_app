import 'package:quiz_monster/ui/settings/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:quiz_monster/data/models/quiz_model.dart';
import 'package:quiz_monster/ui/common/layout/default_layout.dart';
import 'package:quiz_monster/ui/common/widgets/error_message_widget.dart';
import 'package:quiz_monster/ui/quiz/base/quiz_screen.dart';
import 'package:quiz_monster/ui/quiz_settings/player/set_player_screen.dart';
import 'package:quiz_monster/ui/wishlist/wishlist_screen.dart';
import 'package:quiz_monster/ui/quiz/detail/quiz_detail_screen.dart';
import 'package:quiz_monster/ui/quiz_settings/level/set_level_screen.dart';
import 'package:quiz_monster/ui/quiz/pass/pass_result_screen.dart';
import 'package:quiz_monster/ui/quiz_settings/time/time_count_screen.dart';
import 'package:quiz_monster/ui/quiz_settings/time/set_time_screen.dart';
import '../../ui/quiz_settings/pass/set_pass_screen.dart';
import '../../test/test_screen.dart';

final goRouterProvider = Provider((ref) {
  return GoRouter(
    initialLocation: '/quiz',
    routes: [
      GoRoute(
        path: '/quiz',
        name: QuizScreen.routeName,
        pageBuilder: (context, state) =>
            buildSlidePage(context, state, child: QuizScreen()),
      ),
      GoRoute(
        path: '/wishlist',
        name: WishlistScreen.routeName,
        pageBuilder: (context, state) {
          final items = state.extra;
          if (items is! List<QuizModel>) {
            return buildSlidePage(
              context,
              state,
              child: DefaultLayout(
                child: ErrorMessageWidget(
                  message: '찜 목록을 불러올 수 없습니다.\n퀴즈 목록에서 다시 열어 주세요.',
                  onTap: () => context.goNamed(QuizScreen.routeName),
                  label: '목록으로',
                ),
              ),
            );
          }
          return buildSlidePage(
            context,
            state,
            child: WishlistScreen(items),
          );
        },
      ),
      GoRoute(
        path: '/test',
        name: TestScreen.routeName,
        pageBuilder: (context, state) =>
            buildSlidePage(context, state, child: TestScreen()),
      ),

      GoRoute(
        path: '/settings',
        name: SettingsScreen.routeName,
        pageBuilder: (context, state) => buildSlidePage(
          context,
          state,
          child: const SettingsScreen(),
        ),
      ),

      /// Quiz settings
      GoRoute(
        path: '/pass',
        name: SetPassScreen.routeName,
        pageBuilder: (context, state) =>
            buildSlidePage(context, state, child: SetPassScreen()),
      ),
      GoRoute(
        path: '/level',
        name: SetLevelScreen.routeName,
        pageBuilder: (context, state) =>
            buildSlidePage(context, state, child: SetLevelScreen()),
      ),
      GoRoute(
        path: '/time',
        name: SetTimeScreen.routeName,
        pageBuilder: (context, state) =>
            buildSlidePage(context, state, child: SetTimeScreen()),
      ),
      GoRoute(
        path: '/player',
        name: PlayerScreen.routeName,
        pageBuilder: (context, state) =>
            buildSlidePage(context, state, child: PlayerScreen()),
      ),
      GoRoute(
        path: '/time-count',
        name: TimeCountScreen.routeName,
        pageBuilder: (context, state) =>
            buildSlidePage(context, state, child: TimeCountScreen()),
      ),

      /// Quiz
      GoRoute(
        path: '/quiz-detail/:qid',
        name: QuizDetailScreen.routeName,
        pageBuilder: (context, state) {
          final qid = int.tryParse(state.pathParameters['qid'] ?? '');
          if (qid == null || qid <= 0) {
            return buildSlidePage(
              context,
              state,
              child: DefaultLayout(
                child: ErrorMessageWidget(
                  message: '퀴즈 주소를 확인할 수 없습니다.\n목록에서 다시 선택해 주세요.',
                  onTap: () => context.goNamed(QuizScreen.routeName),
                  label: '목록으로',
                ),
              ),
            );
          }
          return buildSlidePage(
            context,
            state,
            child: QuizDetailScreen(qid),
          );
        },
      ),
      GoRoute(
        path: '/result',
        name: ResultScreen.routeName,
        pageBuilder: (context, state) =>
            buildSlidePage(context, state, child: ResultScreen()),
      ),
    ],
  );
});

Page<T> buildSlidePage<T>(
  BuildContext context,
  GoRouterState state, {
  required Widget child,
}) {
  if (Theme.of(context).platform == TargetPlatform.iOS) {
    return CupertinoPage<T>(
      key: state.pageKey,
      name: state.name,
      child: child,
    );
  }

  // Android는 같은 슬라이드만 적용하고 iOS 가장자리 제스처는 추가하지 않는다.
  return CustomTransitionPage<T>(
    key: state.pageKey,
    name: state.name,
    transitionDuration:
        CupertinoRouteTransitionMixin.kTransitionDuration,
    reverseTransitionDuration:
        CupertinoRouteTransitionMixin.kTransitionDuration,
    child: child,
    transitionsBuilder: (_, animation, secondaryAnimation, child) =>
        CupertinoPageTransition(
          primaryRouteAnimation: animation,
          secondaryRouteAnimation: secondaryAnimation,
          linearTransition: false,
          child: child,
        ),
  );
}
