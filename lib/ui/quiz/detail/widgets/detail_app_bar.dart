import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quiz_monster/core/theme/theme_provider.dart';
import 'package:quiz_monster/ui/quiz/detail/widgets/timer_widget.dart';

class DetailAppBar extends ConsumerWidget {
  final int itemLength;
  final int currentIndex;
  final AnimationController animationController;
  final int remainingSeconds;
  final VoidCallback onBackPressed;
  const DetailAppBar({
    super.key,
    required this.itemLength,
    required this.currentIndex,
    required this.animationController,
    required this.remainingSeconds,
    required this.onBackPressed,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.read(themeServiceProvider);

    return AppBar(
      leading: IconButton(
        icon: Icon(
          Icons.arrow_back_ios,
          color: theme.color.onPrimary,
        ),
        onPressed: onBackPressed,
      ),
      centerTitle: true,
      title: TimerWidget(
        animationController: animationController,
        remainingSeconds: remainingSeconds,
      ),
      actionsPadding: EdgeInsets.symmetric(horizontal: 8),
      actions: [
        if (itemLength != 0)
          Text(
            currentIndex == itemLength
                ? '$itemLength/$itemLength'
                : '${currentIndex + 1}/$itemLength',
            style: theme.typo.headline6,
          ),
      ],
    );
  }
}
