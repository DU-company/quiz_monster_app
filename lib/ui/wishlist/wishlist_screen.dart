import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:quiz_monster/ui/ad/banner_ad_view_model.dart';
import 'package:quiz_monster/core/theme/theme_provider.dart';
import 'package:quiz_monster/data/models/pagination_state.dart';
import 'package:quiz_monster/data/models/quiz_model.dart';
import 'package:quiz_monster/ui/common/layout/default_layout.dart';
import 'package:quiz_monster/ui/quiz/base/quiz_view_model.dart';
import 'package:quiz_monster/ui/quiz/base/widgets/quiz_card.dart';
import 'package:quiz_monster/ui/quiz/base/widgets/start_quiz_dialog.dart';
import 'package:quiz_monster/ui/wishlist/wishlist_view_model.dart';

class WishlistScreen extends ConsumerWidget {
  static String routeName = 'wishlist';

  final List<QuizModel> items;
  const WishlistScreen(this.items);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.read(themeServiceProvider);
    final wishlist = ref.watch(wishlistViewModelProvider);

    final pList = items
        .where((model) => wishlist.contains(model.id))
        .toList();
    return DefaultLayout(
      backgroundColor: theme.color.onPrimary,
      appBar: AppBar(
        backgroundColor: theme.color.onSecondary,
        foregroundColor: theme.color.secondary,
        centerTitle: false,
        titleSpacing: 0,
        title: Text(
          '위시리스트',
          style: theme.typo.headline5.copyWith(
            color: theme.color.secondary,
          ),
        ),
      ),

      /// Wishlist
      child: Column(
        children: [
          if (pList.isEmpty)
            Expanded(
              child: Center(
                child: Text(
                  '위시리스트가 비어있습니다.',
                  style: theme.typo.subtitle1.copyWith(
                    color: theme.color.secondary,
                  ),
                ),
              ),
            ),
          if (pList.isNotEmpty)
            Expanded(
              child: ListView.separated(
                physics: BouncingScrollPhysics(),
                itemCount: pList.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final model = pList[index];
                  return GestureDetector(
                    onTap: () => onTapCard(context, ref, model),
                    child: QuizCard.fromModel(
                      model: model,
                      isLiked: true,
                      onLikePressed: () => ref
                          .read(wishlistViewModelProvider.notifier)
                          .toggleLike(model),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
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
