import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_svg/svg.dart';
import 'package:quiz_monster/core/theme/theme_provider.dart';
import 'package:quiz_monster/ui/common/widgets/loading_widget.dart';
import 'package:quiz_monster/ui/common/widgets/primary_button.dart';
import 'package:quiz_monster/core/theme/responsive/layout.dart';
import 'package:quiz_monster/ui/quiz/detail/widgets/quiz_detail_success_view.dart';
import 'package:quiz_monster/ui/common/layout/quiz_detail_layout.dart';
import 'package:quiz_monster/ui/quiz/etc/fly/fly_view_model.dart';
import 'package:quiz_monster/ui/quiz_settings/level/level_provider.dart';

class FlyScreen extends ConsumerStatefulWidget {
  final VoidCallback showAnswerPressed;
  final VoidCallback onReplay;
  final int remainingSeconds;
  const FlyScreen({
    super.key,
    required this.showAnswerPressed,
    required this.onReplay,
    required this.remainingSeconds,
  });
  @override
  _FlyScreenState createState() => _FlyScreenState();
}

class _FlyScreenState extends ConsumerState<FlyScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(flyViewModelProvider.notifier).initFlies(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.read(themeServiceProvider);
    final showAnswer = ref.watch(showAnswerProvider);
    final state = ref.watch(flyViewModelProvider);

    if (state.flyPositions.isEmpty) {
      return LoadingWidget();
    }

    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Stack(
              children: [
                // 랜덤하게 배치된 파리들
                ...state.flyPositions.map(
                  (pos) => Positioned(
                    left: pos.dx,
                    top: pos.dy,
                    child: SvgPicture.asset(
                      'assets/img/fly.svg',
                      width: context.layout(80, mobile: 64),
                      height: context.layout(80, mobile: 64),
                    ),
                  ),
                ),
              ],
            ),
          ),
          _TimeOver(remainingSeconds: widget.remainingSeconds),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: PrimaryButton(
                  backgroundColor: theme.color.onSecondary,
                  foregroundColor: theme.color.secondary,
                  label: '새로 고침',
                  child: Icon(Icons.refresh, size: 24),
                  onPressed: () {
                    ref
                        .read(flyViewModelProvider.notifier)
                        .initFlies(context);
                    widget.onReplay();
                  },
                ),
              ),
              Expanded(
                child: Text(
                  showAnswer ? '${state.flyCount} 마리' : '',
                  textAlign: TextAlign.center,
                  style: theme.typo.headline6.copyWith(
                    fontSize: context.layout(48, mobile: 18),
                  ),
                ),
              ),
              Expanded(
                child: PrimaryButton(
                  label: '정답',
                  onPressed: widget.showAnswerPressed,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TimeOver extends StatelessWidget {
  final int remainingSeconds;
  const _TimeOver({super.key, required this.remainingSeconds});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Text(
        remainingSeconds == 0 ? '💣 TIME OVER 💣' : "",
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 32,
          fontFamily: 'Roboto',
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
