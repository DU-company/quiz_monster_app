import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:quiz_monster/data/models/quiz_model.dart';
import 'package:quiz_monster/ui/quiz/base/quiz_screen.dart';
import 'package:quiz_monster/ui/settings/player/set_player_screen.dart';
import 'package:quiz_monster/ui/quiz/etc/reaction/reaction_rate_screen.dart';
import 'package:quiz_monster/ui/wishlist/wishlist_screen.dart';
import 'package:quiz_monster/ui/quiz/detail/quiz_detail_screen.dart';
import 'package:quiz_monster/ui/settings/level/set_level_screen.dart';
import 'package:quiz_monster/ui/quiz/pass/pass_result_screen.dart';
import 'package:quiz_monster/ui/settings/time/time_count_screen.dart';
import 'package:quiz_monster/ui/settings/time/set_time_screen.dart';
import '../../ui/settings/pass/set_pass_screen.dart';
import '../../test/test_screen.dart';

final goRouterProvider = Provider((ref) {
  return GoRouter(
    initialLocation: '/quiz',
    routes: [
      GoRoute(
        path: '/quiz',
        name: QuizScreen.routeName,
        pageBuilder: (_, _) => _slidePage(child: QuizScreen()),
      ),
      GoRoute(
        path: '/wishlist',
        name: WishlistScreen.routeName,
        pageBuilder: (_, state) {
          final items = state.extra as List<QuizModel>;
          return _slidePage(child: WishlistScreen(items));
        },
      ),
      GoRoute(
        path: '/test',
        name: TestScreen.routeName,
        pageBuilder: (_, _) => _slidePage(child: TestScreen()),
      ),

      /// Settings
      GoRoute(
        path: '/pass',
        name: SetPassScreen.routeName,
        pageBuilder: (_, _) => _slidePage(child: SetPassScreen()),
      ),
      GoRoute(
        path: '/level',
        name: SetLevelScreen.routeName,
        pageBuilder: (_, _) => _slidePage(child: SetLevelScreen()),
      ),
      GoRoute(
        path: '/time',
        name: SetTimeScreen.routeName,
        pageBuilder: (_, _) => _slidePage(child: SetTimeScreen()),
      ),
      GoRoute(
        path: '/player',
        name: PlayerScreen.routeName,
        pageBuilder: (_, _) => _slidePage(child: PlayerScreen()),
      ),
      GoRoute(
        path: '/time-count',
        name: TimeCountScreen.routeName,
        pageBuilder: (_, _) => _slidePage(child: TimeCountScreen()),
      ),

      /// Quiz
      GoRoute(
        path: '/quiz-detail/:qid',
        name: QuizDetailScreen.routeName,
        pageBuilder: (_, state) {
          final qid = int.parse(state.pathParameters['qid']!);
          return _slidePage(child: QuizDetailScreen(qid));
        },
      ),
      GoRoute(
        path: '/result',
        name: ResultScreen.routeName,
        pageBuilder: (_, _) => _slidePage(child: ResultScreen()),
      ),

      GoRoute(
        path: '/reaction',
        name: ReactionRateScreen.routeName,
        pageBuilder: (_, _) => _slidePage(child: ReactionRateScreen()),
      ),
    ],
  );
});

CustomTransitionPage<T> _slidePage<T>({
  required Widget child,
  Duration duration = const Duration(milliseconds: 250),
}) {
  return CustomTransitionPage<T>(
    transitionDuration: duration,
    reverseTransitionDuration: duration,
    child: child,
    transitionsBuilder:
        (context, animation, secondaryAnimation, child) {
          final tween = Tween<Offset>(
            begin: const Offset(1.0, 0.0),
            end: Offset.zero,
          ).chain(CurveTween(curve: Curves.easeOutCubic));

          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        },
  );
}
