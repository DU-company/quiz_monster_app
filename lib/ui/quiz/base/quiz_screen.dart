import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:quiz_monster/core/theme/theme_provider.dart';
import 'package:quiz_monster/data/models/pagination_state.dart';
import 'package:quiz_monster/data/models/quiz_model.dart';
import 'package:quiz_monster/ui/ad/banner_ad_view_model.dart';
import 'package:quiz_monster/ui/common/layout/default_layout.dart';
import 'package:quiz_monster/ui/common/widgets/error_message_widget.dart';
import 'package:quiz_monster/ui/common/widgets/loading_widget.dart';
import 'package:quiz_monster/ui/quiz/base/quiz_view_model.dart';
import 'package:quiz_monster/ui/quiz/base/widgets/quiz_success_view.dart';

class QuizScreen extends ConsumerWidget {
  static String get routeName => 'quiz';
  const QuizScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quizState = ref.watch(quizViewModelProvider);
    final theme = ref.read(themeServiceProvider);
    ref.watch(bannerAdViewModelProvider);

    return DefaultLayout(
      needWillPopScope: true,
      needPadding: false,
      needSafeArea: false,
      backgroundColor: quizState is PaginationSuccess
          ? theme.color.onPrimary
          : theme.color.primary,
      child: _body(quizState, ref),
    );
  }

  Widget _body(PaginationState state, WidgetRef ref) {
    if (state is PaginationLoading) {
      return LoadingWidget();
    }
    if (state is PaginationError) {
      return ErrorMessageWidget(
        message: state.message,
        onTap: () =>
            ref.read(quizViewModelProvider.notifier).getQuizList(),
        label: '다시시도',
      );
    }

    state as PaginationSuccess<QuizModel>;
    return QuizSuccessView(state.items);
  }
}
