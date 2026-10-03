import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:quiz_monster/core/provider/selected_quiz_provider.dart';
import 'package:quiz_monster/core/theme/responsive/layout.dart';
import 'package:quiz_monster/core/theme/theme_provider.dart';
import 'package:quiz_monster/ui/common/widgets/error_message_widget.dart';
import 'package:quiz_monster/ui/quiz/base/quiz_screen.dart';

import 'default_layout.dart';

class SettingLayout extends ConsumerWidget {
  final String label;
  final Widget body;
  final Widget footer;
  const SettingLayout({
    super.key,
    required this.label,
    required this.body,
    required this.footer,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedQuiz = ref.watch(selectedQuizProvider);

    if (selectedQuiz == null) {
      return DefaultLayout(
        child: ErrorMessageWidget(
          message: '퀴즈를 다시 선택해 주세요.',
          label: '홈으로',
          onTap: () => context.goNamed(QuizScreen.routeName),
        ),
      );
    }

    return DefaultLayout(
      appBar: AppBar(title: Text(selectedQuiz.title)),
      child: context.layout(
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Spacer(),
            _Top(label: label),
            Spacer(),
            body,
            Spacer(),
            footer,
          ],
        ),

        /// Desktop
        desktop: Row(
          children: [
            Expanded(child: _Top(label: label)),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [Spacer(), body, Spacer(), footer],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Top extends ConsumerWidget {
  final String label;
  const _Top({super.key, required this.label});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.read(themeServiceProvider);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SvgPicture.asset(
          'assets/img/eyes1.svg',
          height: 100,
          fit: BoxFit.cover,
        ),
        const SizedBox(height: 8),
        Text(
          style: theme.typo.headline6,
          textAlign: TextAlign.center,
          label,
        ),
      ],
    );
  }
}
