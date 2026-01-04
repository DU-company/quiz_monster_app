import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quiz_monster/core/provider/page_controller_provider.dart';
import 'package:quiz_monster/core/theme/theme_provider.dart';
import 'package:quiz_monster/data/models/quiz_detail_model.dart';
import 'package:quiz_monster/ui/common/widgets/primary_button.dart';
import 'package:quiz_monster/ui/settings/player/set_player_view_model.dart';

class LiarBody extends ConsumerWidget {
  final List<QuizDetailModel> items;
  final PageController pageController;
  final int playerCount;
  final bool showAnswer;
  final int currentIndex;
  final int liarIndex;
  final bool isLastPage;
  final VoidCallback onTapButton;
  const LiarBody({
    super.key,
    required this.pageController,
    required this.playerCount,
    required this.showAnswer,
    required this.currentIndex,
    required this.liarIndex,
    required this.items,
    required this.isLastPage,
    required this.onTapButton,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.read(themeServiceProvider);

    return Expanded(
      child: PageView.builder(
        controller: pageController,
        physics: NeverScrollableScrollPhysics(),
        itemCount: playerCount + 1,
        itemBuilder: (context, index) {
          final model = items.first;
          final isLiar = index == liarIndex;
          return Padding(
            padding: EdgeInsets.symmetric(horizontal: 2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                /// Label
                Text(
                  index == playerCount
                      ? '자유롭게 토론을 진행하세요!'
                      : '혼자만 보세요!',
                  style: theme.typo.headline6,
                ),
                const SizedBox(height: 8),

                /// Box
                _AnswerBox(
                  currentIndex: currentIndex,
                  isLiar: isLiar,
                  isLastPage: isLastPage,
                  showAnswer: showAnswer,
                  answer: model.answer,
                  onTapButton: onTapButton,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _AnswerBox extends ConsumerWidget {
  final int currentIndex;
  final bool isLiar;
  final bool isLastPage;
  final bool showAnswer;
  final String answer;
  final VoidCallback onTapButton;
  const _AnswerBox({
    super.key,
    required this.currentIndex,
    required this.isLiar,
    required this.isLastPage,
    required this.showAnswer,
    required this.answer,
    required this.onTapButton,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.read(themeServiceProvider);
    return Container(
      height: 160,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (!isLastPage)
              Text(
                'PLAYER ${currentIndex + 1}',
                style: theme.typo.subtitle1.copyWith(
                  color: theme.color.secondary,
                ),
              ),
            if (!isLastPage) const SizedBox(height: 16),
            if (showAnswer)
              Text(
                isLiar ? '당신은 라이어 입니다.\n있는 힘 껏 아는 척을 해 주세요.' : answer,
                textAlign: TextAlign.center,
                style: theme.typo.headline6.copyWith(
                  color: theme.color.secondary,
                ),
              ),
            if (!showAnswer)
              Center(
                child: PrimaryButton(
                  label: isLastPage ? '토론 끝내고 정답 보기' : '단어 보기',
                  onPressed: (isLastPage && showAnswer)
                      ? null
                      : onTapButton,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
