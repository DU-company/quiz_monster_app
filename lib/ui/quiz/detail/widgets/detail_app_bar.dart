import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quiz_monster/core/theme/theme_provider.dart';
import 'package:quiz_monster/core/utils/data_utils.dart';
import 'package:quiz_monster/ui/quiz/detail/widgets/exit_dialog.dart';
import 'package:quiz_monster/ui/quiz/detail/widgets/timer_widget.dart';

class DetailAppBar extends ConsumerWidget {
  final int itemLength;
  final int currentIndex;
  final AnimationController animationController;
  final int remainingSeconds;
  final VoidCallback onTapConfirm;
  const DetailAppBar({
    super.key,
    required this.itemLength,
    required this.currentIndex,
    required this.animationController,
    required this.remainingSeconds,
    required this.onTapConfirm,
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
        onPressed: () => onPop(context),
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

  void onPop(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => ExitDialog(onTapConfirm: onTapConfirm),
    );
  }
}
