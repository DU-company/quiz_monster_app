import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quiz_monster/core/const/data.dart';
import 'package:quiz_monster/core/theme/app_theme.dart';
import 'package:quiz_monster/core/theme/theme_provider.dart';

class QuizCategoryList extends ConsumerWidget {
  final void Function(int) onPressed;
  final int currentIndex;
  const QuizCategoryList({
    super.key,
    required this.onPressed,
    required this.currentIndex,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.read(themeServiceProvider);

    return SliverToBoxAdapter(
      child: SizedBox(
        height: 50,
        child: ListView.builder(
          physics: BouncingScrollPhysics(),
          scrollDirection: Axis.horizontal,
          itemCount: CATEGORIES.length,
          itemBuilder: (context, index) {
            /// 마지막 카테고리는 <기타 게임>
            if (index == CATEGORIES.length) {
              return renderCategoryButton(index, '기타 게임', theme);
            }

            /// 일반 카테고리 목록
            return renderCategoryButton(
              index,
              CATEGORIES[index],
              theme,
            );
          },
        ),
      ),
    );
  }

  Widget renderCategoryButton(
    int index,
    String label,
    AppTheme theme,
  ) {
    return TextButton(
      style: TextButton.styleFrom(
        foregroundColor: theme.color.onSecondary,
        backgroundColor: Colors.transparent,
      ),
      onPressed: () => onPressed(index),
      child: Text(
        label,
        style: theme.typo.subtitle2.copyWith(
          color: index == currentIndex
              ? theme.color.secondary
              : theme.color.subtext,
          fontWeight: index == currentIndex
              ? theme.typo.semiBold
              : theme.typo.regular,
        ),
      ),
    );
  }
}
