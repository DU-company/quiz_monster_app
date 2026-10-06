import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:quiz_monster/ui/ad/ad_finished_provider.dart';
import 'package:quiz_monster/ui/ad/interstitial_ad_view_model.dart';
import 'package:quiz_monster/ui/common/layout/quiz_detail_layout.dart';
import 'package:quiz_monster/ui/common/widgets/primary_button.dart';
import 'package:quiz_monster/ui/common/layout/default_layout.dart';
import 'package:quiz_monster/ui/quiz/base/quiz_screen.dart';
import 'package:quiz_monster/ui/quiz/detail/widgets/exit_dialog.dart';
import 'package:quiz_monster/ui/quiz/etc/reaction/view_model/reaction_view_model.dart';
import 'package:quiz_monster/ui/quiz/etc/reaction/widgets/reaction_app_bar.dart';
import 'package:quiz_monster/ui/quiz/etc/reaction/widgets/reaction_average_box.dart';
import 'package:quiz_monster/ui/quiz/etc/reaction/widgets/reaction_circle.dart';
import 'package:quiz_monster/ui/quiz/etc/reaction/widgets/replay_dialog.dart';

class ReactionRateScreen extends ConsumerWidget {
  const ReactionRateScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewModel = ref.read(reactionViewModelProvider.notifier);
    final reactionState = ref.watch(reactionViewModelProvider);
    ref.listen(adFinishedProvider, (p, n) async {
      if (n == true) {
        viewModel.resetScreen();
        ref.read(adFinishedProvider.notifier).onReset();
      }
    });

    // 단계 끝
    final isStepOver =
        reactionState.isGreen && reactionState.result.isNotEmpty;
    // 게임 끝
    final isGameOver =
        reactionState.currentStep == 5 &&
        reactionState.result.isNotEmpty;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && (ModalRoute.of(context)?.isCurrent ?? false)) {
          onTapBack(context);
        }
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          /// AppBar
          ReactionAppBar(
            onTapBack: () => onTapBack(context),
            step: reactionState.currentStep,
          ),
          // UI 멈춤 방지
          CircularProgressIndicator(color: Colors.transparent),
          QuizDetailLayout(
            /// Body
            body: isGameOver
                ? ReactionAverageBox(
                    testResults: reactionState.resultList,
                  )
                : ReactionCircle(
                    onTapCircle: viewModel.onTapCircle,
                    isGreen: reactionState.isGreen,
                    label: reactionState.result,
                  ),

            /// Footer
            footer: PrimaryButton(
              label: isGameOver ? '다시 시작' : '다음',
              onPressed: isStepOver
                  ? isGameOver
                        ? () => shoReplayDialog(context, ref)
                        : viewModel.onTapNext
                  : null,
            ),
          ),
        ],
      ),
    );
  }

  void onTapBack(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => ExitDialog(
        onTapConfirm: () {
          context.pop();
          context.goNamed(QuizScreen.routeName);
        },
      ),
    );
  }

  void shoReplayDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) {
        return RecationReplayDialog(
          onTapReplay: () {
            context.pop();
            ref
                .read(interstitialAdViewModelProvider.notifier)
                .showAd();
          },
        );
      },
    );
  }
}
