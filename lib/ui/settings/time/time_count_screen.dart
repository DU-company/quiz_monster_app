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
  double _opacity = 1.0;
  final AudioPlayer _player = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  void _playBeepSound() async {
    await _player.play(AssetSource('beep.mp3')); // 효과음 파일 추가 필요
  }

  void _startCountdown() async {
    await Future.delayed(Duration(milliseconds: 1500));
    _changeNumber(3);
    _playBeepSound(); // 효과음 재생

    Future.delayed(Duration(seconds: 1), () {
      _changeNumber(2);
    });
    Future.delayed(Duration(seconds: 2), () {
      _changeNumber(1);
    });
    Future.delayed(Duration(seconds: 3), () {
      _changeNumber(0); // "Start!" 표시
    });
    Future.delayed(Duration(seconds: 4), () {
      _goToQuizScreen(); // 퀴즈 화면 이동
    });
  }

  void _changeNumber(int num) {
    setState(() {
      _opacity = 0.0; // 먼저 페이드아웃
    });
    Future.delayed(Duration(milliseconds: 100), () {
      setState(() {
        _currentNumber = num == 0 ? -1 : num;
        _opacity = 1.0; // 다시 페이드인
      });
      // if (num > 0)
    });
  }

  void _goToQuizScreen() {
    final selectedModel = ref.read(selectedQuizProvider);
    context.goNamed(
      QuizDetailScreen.routeName,
      pathParameters: {'qid': '${selectedModel!.id}'},
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.read(themeServiceProvider);
    final selectedQuiz = ref.watch(selectedQuizProvider);
    ref.watch(timeViewModelProvider);
    ref.watch(quizDetailViewModelProvider(selectedQuiz!.id));
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
