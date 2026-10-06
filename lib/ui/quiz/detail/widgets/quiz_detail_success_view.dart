import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:go_router/go_router.dart';
import 'package:quiz_monster/data/models/quiz_detail_model.dart';
import 'package:quiz_monster/data/models/quiz_model.dart';
import 'package:quiz_monster/data/models/quiz_type.dart';
import 'package:quiz_monster/ui/quiz/base/quiz_screen.dart';
import 'package:quiz_monster/core/provider/page_controller_provider.dart';
import 'package:quiz_monster/ui/quiz/etc/fly/fly_screen.dart';
import 'package:quiz_monster/ui/quiz/no_pass/no_pass_quiz_screen.dart';
import 'package:quiz_monster/ui/quiz/pass/pass_quiz_screen.dart';
import 'package:quiz_monster/ui/quiz/detail/view_model/detail_timer_view_model.dart';
import 'package:quiz_monster/ui/quiz/detail/widgets/detail_app_bar.dart';
import 'package:quiz_monster/ui/quiz_settings/level/level_provider.dart';
import 'package:quiz_monster/ui/quiz_settings/time/set_time_view_model.dart';

final showAnswerProvider = StateProvider.autoDispose<bool>(
  (ref) => false,
);

final currentIndexProvider = StateProvider<int>((ref) => 0);

class QuizDetailSuccessView extends ConsumerStatefulWidget {
  final QuizModel quiz;
  final List<QuizDetailModel> items;
  const QuizDetailSuccessView({
    required this.quiz,
    required this.items,
  });

  @override
  ConsumerState<QuizDetailSuccessView> createState() =>
      _QuizScreenState();
}

class _QuizScreenState extends ConsumerState<QuizDetailSuccessView>
    with SingleTickerProviderStateMixin {
  final AudioPlayer player = AudioPlayer();
  late AnimationController animationController;

  @override
  void initState() {
    final time = ref.read(timeViewModelProvider);
    animationController = AnimationController(
      vsync: this,
      duration: time,
    )..forward();
    super.initState();
  }

  @override
  void dispose() {
    animationController.dispose();
    player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final showAnswer = ref.watch(showAnswerProvider);
    final currentIndex = ref.watch(currentIndexProvider);
    final remainingSeconds = ref.watch(detailTimerViewModelProvider);
    final pageController = ref.watch(pageControllerProvider);
    ref.watch(timeViewModelProvider);

    if (!showAnswer && remainingSeconds == 3) {
      playSound();
    }

    return Column(
      children: [
        DetailAppBar(
          itemLength: widget.items.length,
          currentIndex: currentIndex,
          animationController: animationController,
          remainingSeconds: remainingSeconds,
          onTapConfirm: onTapConfirm,
        ),

        /// Pass
        if (widget.quiz.type == QuizType.pass)
          PassQuizScreen(
            items: widget.items,
            pageController: pageController,
            remainingSeconds: remainingSeconds,
          ),

        /// NoPass
        if (widget.quiz.type == QuizType.image ||
            widget.quiz.type == QuizType.question)
          NoPassQuizScreen(
            items: widget.items,
            remainingSeconds: remainingSeconds,
            pageController: pageController,
            onNextPressed: onNextPressed,
            onPrevPressed: onPrevPressed,
            showAnswerPressed: showAnswerPressed,
          ),

        /// ETC
        if (widget.quiz.type == QuizType.fly)
          FlyScreen(
            showAnswerPressed: showAnswerPressed,
            onReplay: onReplay,
            remainingSeconds: remainingSeconds,
          ),
      ],
    );
  }

  void playSound() async {
    await player.play(
      AssetSource('three_counts.mp3'),
    ); // 효과음 파일 추가 필요
  }

  void stopSound() {
    player.stop();
  }

  void restartAnimation() {
    animationController.reset();
    animationController.forward();
  }

  void allStop() {
    stopSound();
    animationController.stop();
    ref.read(detailTimerViewModelProvider.notifier).stopTimer();
    ref.read(showAnswerProvider.notifier).state = false;
  }

  void onPrevPressed() {
    ref.read(pageControllerProvider.notifier).previousPage();
    allStop();
  }

  /// 파리가 몇 마리?
  void onReplay() {
    stopSound();
    restartAnimation();
    ref.read(showAnswerProvider.notifier).state = false;
    ref.read(detailTimerViewModelProvider.notifier).restartTimer();
  }

  void onNextPressed() {
    onReplay();
    ref.read(pageControllerProvider.notifier).nextPage();
  }

  void showAnswerPressed() {
    allStop();
    ref.read(showAnswerProvider.notifier).state = true;
  }

  // pop
  void onTapConfirm() {
    // pop dialog
    context.pop();
    ref.read(showAnswerProvider.notifier).state = false;
    ref.read(levelProvider.notifier).state = null;
    stopSound();
    ref.read(currentIndexProvider.notifier).state = 0;

    context.goNamed(QuizScreen.routeName);
  }
}
