import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:quiz_monster/ui/quiz/base/quiz_screen.dart';
import 'package:quiz_monster/ui/quiz/etc/liar/liar_screen.dart';
import 'package:quiz_monster/ui/quiz/detail/view_model/quiz_detail_state.dart';
import 'package:quiz_monster/ui/quiz/detail/widgets/quiz_detail_success_view.dart';
import 'package:quiz_monster/ui/common/layout/default_layout.dart';
import 'package:quiz_monster/ui/common/widgets/error_message_widget.dart';
import 'package:quiz_monster/ui/common/widgets/loading_widget.dart';
import 'package:quiz_monster/ui/quiz/detail/view_model/quiz_detail_view_model.dart';
import 'package:quiz_monster/ui/quiz/etc/reaction/reaction_rate_screen.dart';
import 'package:quiz_monster/data/models/quiz_type.dart';

class QuizDetailScreen extends ConsumerWidget {
  static String get routeName => 'quiz-detail';
  final int qid;
  const QuizDetailScreen(this.qid, {super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailState = ref.watch(quizDetailViewModelProvider(qid));
    return DefaultLayout(
      needPadding: true,
      child: _body(detailState, context),
    );
  }

  Widget _body(QuizDetailState state, BuildContext context) {
    if (state is QuizDetailLoading) {
      return LoadingWidget();
    }
    if (state is QuizDetailError) {
      return ErrorMessageWidget(
        message: state.message,
        onTap: () => context.goNamed(QuizScreen.routeName),
        label: '홈으로',
      );
    }
    state as QuizDetailSuccess;
    if (state.quiz.type != QuizType.fly &&
        state.quiz.type != QuizType.reaction &&
        state.items.isEmpty) {
      return ErrorMessageWidget(
        message: '선택한 조건에 맞는 문항이 없습니다.\n다른 조건으로 다시 시도해 주세요.',
        onTap: () => context.goNamed(QuizScreen.routeName),
        label: '목록으로',
      );
    }
    // 라이어 게임은 별도의 앱바가 필요 & 다른 게임들과 화면 분리가 필요
    if (state.quiz.type == QuizType.liar) {
      return LiarGameScreen(
        title: state.quiz.title,
        items: state.items,
      );
    }

    // 반응속도 게임은 별도의 앱바가 필요 & 다른 게임들과 화면 분리가 필요
    if (state.quiz.type == QuizType.reaction) {
      return ReactionRateScreen();
    }
    return QuizDetailSuccessView(
      quiz: state.quiz,
      items: state.items,
    );
  }
}
