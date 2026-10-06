import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:quiz_monster/core/theme/color/app_color.dart';
import 'package:quiz_monster/core/theme/responsive/layout.dart';
import 'package:quiz_monster/core/theme/theme_provider.dart';
import 'package:quiz_monster/data/models/quiz_model.dart';
import 'package:quiz_monster/ui/settings/settings_screen.dart';
import 'package:quiz_monster/ui/wishlist/wishlist_screen.dart';

class QuizAppBar extends ConsumerWidget {
  final List<QuizModel> items;
  const QuizAppBar(this.items);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.read(themeServiceProvider);

    return SliverToBoxAdapter(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              /// Top
              renderTop(
                color: theme.color,
                onSettingsPressed: () =>
                    context.pushNamed(SettingsScreen.routeName),
                onLikePressed: () => context.pushNamed(
                  WishlistScreen.routeName,
                  extra: items,
                ),
              ),

              /// Body
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "WHO'S DRUNK?\nLET'S PLAY!🔥",
                    style: TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: context.layout(56, mobile: 28),
                      fontWeight: FontWeight.w500,
                      color: Colors.black,
                    ),
                  ),
                  SvgPicture.asset(
                    'assets/img/eyes2.svg',
                    width: context.layout(150, mobile: 80),
                    fit: BoxFit.cover,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget renderTop({
    required AppColor color,
    required VoidCallback onSettingsPressed,
    required VoidCallback onLikePressed,
  }) {
    return Row(
      children: [
        Text(
          'QUIZ MONSTER',
          style: TextStyle(
            color: color.primary,
            fontFamily: 'Roboto',
            fontWeight: FontWeight.w700,
          ),
        ),
        Spacer(),
        IconButton(
          onPressed: onLikePressed,
          icon: Icon(CupertinoIcons.suit_heart),
        ),
        IconButton(
          tooltip: '환경설정',
          onPressed: onSettingsPressed,
          icon: const Icon(CupertinoIcons.gear),
        ),
      ],
    );
  }
}
