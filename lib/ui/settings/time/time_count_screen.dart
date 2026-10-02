import 'dart:async';

import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:quiz_monster/core/provider/selected_quiz_provider.dart';
import 'package:quiz_monster/core/theme/theme_provider.dart';
import 'package:quiz_monster/ui/ad/banner_ad_view_model.dart';
import 'package:quiz_monster/ui/quiz/etc/liar/liar_screen.dart';
import 'package:quiz_monster/ui/common/layout/default_layout.dart';
import 'package:quiz_monster/ui/common/widgets/error_message_widget.dart';
import 'package:quiz_monster/ui/quiz/base/quiz_screen.dart';
import 'package:quiz_monster/ui/quiz/etc/reaction/reaction_rate_screen.dart';
import 'package:quiz_monster/ui/quiz/detail/quiz_detail_screen.dart';
import 'package:quiz_monster/ui/quiz/detail/view_model/quiz_detail_view_model.dart';
import 'package:quiz_monster/ui/settings/time/set_time_view_model.dart';

class TimeCountScreen extends ConsumerStatefulWidget {
  static String routeName = 'time-count';

  const TimeCountScreen({super.key});
  @override
  _TimeCountScreenState createState() => _TimeCountScreenState();
}

class _TimeCountScreenState extends ConsumerState<TimeCountScreen>
    with SingleTickerProviderStateMixin {
  int? _currentNumber;
  int? _quizId;
  double _opacity = 1.0;
  final AudioPlayer _player = AudioPlayer();
  final List<Timer> _timers = [];

  @override
  void initState() {
    super.initState();
    _quizId = ref.read(selectedQuizProvider)?.id;
    if (_quizId != null) _startCountdown();
  }

  @override
  void dispose() {
    for (final timer in _timers) {
      timer.cancel();
    }
    _player.dispose();
    super.dispose();
  }

  void _playBeepSound() async {
    await _player.play(AssetSource('beep.mp3')); // 효과음 파일 추가 필요
  }

  void _startCountdown() {
    _schedule(Duration(milliseconds: 1500), () {
      _changeNumber(3);
      _playBeepSound();
      _schedule(Duration(seconds: 1), () => _changeNumber(2));
      _schedule(Duration(seconds: 2), () => _changeNumber(1));
      _schedule(Duration(seconds: 3), () => _changeNumber(0));
      _schedule(Duration(seconds: 4), _goToQuizScreen);
    });
  }

  void _schedule(Duration delay, VoidCallback callback) {
    _timers.add(
      Timer(delay, () {
        if (mounted) callback();
      }),
    );
  }

  void _changeNumber(int num) {
    setState(() {
      _opacity = 0.0; // 먼저 페이드아웃
    });
    _schedule(Duration(milliseconds: 100), () {
      setState(() {
        _currentNumber = num == 0 ? -1 : num;
        _opacity = 1.0; // 다시 페이드인
      });
      // if (num > 0)
    });
  }

  void _goToQuizScreen() {
    final selectedModel = ref.read(selectedQuizProvider);
    if (selectedModel == null || selectedModel.id != _quizId) return;
    context.goNamed(
      QuizDetailScreen.routeName,
      pathParameters: {'qid': '${selectedModel.id}'},
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.read(themeServiceProvider);
    final selectedQuiz = ref.watch(selectedQuizProvider);
    if (selectedQuiz == null || selectedQuiz.id != _quizId) {
      return DefaultLayout(
        child: ErrorMessageWidget(
          message: '퀴즈를 다시 선택해 주세요.',
          label: '홈으로',
          onTap: () => context.goNamed(QuizScreen.routeName),
        ),
      );
    }
    ref.watch(timeViewModelProvider);
    ref.watch(quizDetailViewModelProvider(selectedQuiz.id));
    final bannerAd = ref.watch(bannerAdViewModelProvider);

    return DefaultLayout(
      needWillPopScope: true,
      backgroundColor: theme.color.secondary,
      bottomNavigationBar: bannerAd != null
          ? SizedBox(height: 250, child: AdWidget(ad: bannerAd))
          : null,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (_currentNumber == null)
            Text(
              '게임을 준비중입니다...',
              textAlign: TextAlign.center,
              style: theme.typo.headline6,
            ),

          if (_currentNumber != null)
            Center(
              child: AnimatedOpacity(
                duration: Duration(milliseconds: 300),
                opacity: _opacity,
                child: Text(
                  _currentNumber == -1
                      ? "START!"
                      : _currentNumber.toString(),
                  style: theme.typo.headline1.copyWith(fontSize: 60),
                ),
              ),
            ),
          const SizedBox(height: 16),
          if (_currentNumber != null && _currentNumber != -1)
            Text('게임이 곧 시작됩니다...', style: theme.typo.subtitle1),
        ],
      ),
    );
  }
}
