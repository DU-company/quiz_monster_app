import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quiz_monster/core/theme/theme_provider.dart';
import 'package:quiz_monster/core/utils/data_utils.dart';

class TimerWidget extends ConsumerWidget {
  final AnimationController animationController;
  final int remainingSeconds;
  const TimerWidget({
    super.key,
    required this.animationController,
    required this.remainingSeconds,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.read(themeServiceProvider);
    return AnimatedBuilder(
      animation: animationController,
      builder: (context, child) {
        return Stack(
          children: [
            SizedBox(
              height: 52,
              width: 52,
              child: CircularProgressIndicator(
                value: animationController.value,
                strokeWidth: 4.5,
                backgroundColor: Colors.white24,
                valueColor: AlwaysStoppedAnimation<Color>(
                  Colors.white,
                ),
              ),
            ),
            Positioned(
              top: 0,
              bottom: 0,
              right: 0,
              left: 0,
              child: Center(
                child: Text(
                  DataUtils.formatTime(remainingSeconds),
                  style: theme.typo.headline6,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
