import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:quiz_monster/core/theme/theme_provider.dart';
import 'package:quiz_monster/ui/common/widgets/primary_button.dart';
import 'package:quiz_monster/ui/common/widgets/dialog/base_confirm_dialog.dart';
import 'package:quiz_monster/ui/common/layout/default_layout.dart';
import 'package:quiz_monster/core/theme/responsive/layout.dart';
import 'package:quiz_monster/ui/quiz/base/quiz_screen.dart';
import 'package:quiz_monster/ui/quiz/pass/view_model/pass_view_model.dart';

class ResultScreen extends ConsumerWidget {
  static String routeName = 'result';
  const ResultScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(passViewModelProvider);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && (ModalRoute.of(context)?.isCurrent ?? false)) {
          showHomeDialog(context, ref);
        }
      },
      child: DefaultLayout(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: SingleChildScrollView(
                physics: BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Top(
                      correctCount: state.correctWords.length,
                      itemCount: state.itemCount,
                    ),
                    Divider(),
                    _Body(
                      passedWords: state.passedWords,
                      correctWords: state.correctWords,
                    ),
                  ],
                ),
              ),
            ),
            PrimaryButton(
              label: 'Home',
              onPressed: () => onPressed(context, ref),
            ),
          ],
        ),
      ),
    );
  }

  void showHomeDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (dialogContext) => BaseConfirmDialog(
        title: '홈으로',
        content: '퀴즈 결과를 닫고 홈으로 이동할까요?',
        confirmLabel: '홈으로',
        cancelLabel: '취소',
        onTapConfirm: () {
          Navigator.of(dialogContext).pop();
          onPressed(context, ref);
        },
      ),
    );
  }

  void onPressed(BuildContext context, WidgetRef ref) {
    context.goNamed(QuizScreen.routeName);
    ref.read(passViewModelProvider.notifier).reset();
    // 세팅 초기화?
  }
}

class _Top extends ConsumerWidget {
  final int correctCount;
  final int itemCount;

  const _Top({
    super.key,
    required this.correctCount,
    required this.itemCount,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.read(themeServiceProvider);
    final TextStyle ts = theme.typo.headline3.copyWith(
      fontSize: 28,
      fontFamily: 'Roboto',
    );
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SvgPicture.asset(
          'assets/img/wow.svg',
          height: 72,
          fit: BoxFit.cover,
        ),
        const SizedBox(height: 16),
        SvgPicture.asset(
          'assets/img/eyes1.svg',
          height: 72,
          fit: BoxFit.cover,
        ),

        const SizedBox(height: 16),
        Text(
          'YOUR SCORE IS...',
          textAlign: TextAlign.center,
          style: ts.copyWith(fontWeight: FontWeight.w300),
        ),
        const SizedBox(height: 16),
        Text(
          '$correctCount/$itemCount',
          textAlign: TextAlign.center,
          style: ts.copyWith(fontSize: 48),
        ),
      ],
    );
  }
}

class _Body extends StatelessWidget {
  final List<String> passedWords;
  final List<String> correctWords;
  const _Body({
    super.key,
    required this.passedWords,
    required this.correctWords,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _WordBox(words: passedWords, label: 'PASS'),
        Divider(),
        _WordBox(words: correctWords, label: 'CORRECT'),
      ],
    );
  }
}

class _WordBox extends ConsumerWidget {
  final String label;
  final List<String> words;
  const _WordBox({
    super.key,
    required this.words,
    required this.label,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.read(themeServiceProvider);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: theme.typo.headline1.copyWith(
              fontSize: context.layout(48, mobile: 32),
              fontFamily: 'Roboto',
            ),
          ),
        ),
        Wrap(
          alignment: WrapAlignment.spaceEvenly,
          children: List.generate(
            words.length,
            (index) => Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                '[${words[index]}]',
                textAlign: TextAlign.center,
                style: theme.typo.subtitle2.copyWith(
                  fontSize: context.layout(24, mobile: 18),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
