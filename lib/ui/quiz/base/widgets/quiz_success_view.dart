import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:quiz_monster/data/models/quiz_group.dart';
import 'package:quiz_monster/data/models/quiz_model.dart';
import 'package:quiz_monster/ui/quiz/base/widgets/quiz_app_bar.dart';
import 'package:quiz_monster/ui/quiz/base/widgets/quiz_card.dart';
import 'package:quiz_monster/ui/common/layout/default_layout.dart';
import 'package:quiz_monster/ui/quiz/base/widgets/quiz_category_list.dart';
import 'package:quiz_monster/ui/quiz/base/widgets/start_quiz_dialog.dart';
import 'package:quiz_monster/ui/wishlist/wishlist_view_model.dart';

final _indexProvider = StateProvider((ref) => 0);

const _groups = [
  QuizGroup.guess,
  QuizGroup.liar,
  QuizGroup.continuation,
  QuizGroup.charades,
  QuizGroup.speed,
  QuizGroup.other,
];

class QuizSuccessView extends ConsumerWidget {
  final List<QuizModel> items;
  const QuizSuccessView(this.items, {super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wishlist = ref.watch(wishlistViewModelProvider);
    final currentIndex = ref.watch(_indexProvider);

    final group = _groups[currentIndex];
    final pList = items
        .where((model) => model.group == group)
        .toList();
    return CustomScrollView(
      physics: BouncingScrollPhysics(),
      slivers: [
        QuizAppBar(items),
        QuizCategoryList(
          onPressed: (index) {
            ref.read(_indexProvider.notifier).state = index;
          },
          currentIndex: currentIndex,
        ),
        SliverPadding(
          padding: EdgeInsets.only(right: 8, left: 8, bottom: 32),
          sliver: SliverList.separated(
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemCount: pList.length,
            itemBuilder: (context, index) {
              final model = pList[index];
              final isLiked = wishlist.any((id) => id == model.id);

              return GestureDetector(
                onTap: () => onTapCard(context, ref, model),
                child: QuizCard.fromModel(
                  isLiked: isLiked,
                  onLikePressed: () => ref
                      .read(wishlistViewModelProvider.notifier)
                      .toggleLike(model),
                  model: model,
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void onTapCard(
    BuildContext context,
    WidgetRef ref,
    QuizModel model,
  ) {
    showDialog(
      context: context,
      builder: (context) => StartQuizDialog(model: model),
    );
  }
}
