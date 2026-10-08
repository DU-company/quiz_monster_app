import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quiz_monster/core/provider/selected_quiz_provider.dart';
import 'package:quiz_monster/data/repositories/quiz_statistics_repository.dart';

final quizStartStatisticsProvider =
    NotifierProvider<QuizStartStatistics, void>(
      QuizStartStatistics.new,
    );

class QuizStartStatistics extends Notifier<void> {
  @override
  void build() {}

  // 통계 API 전송: 선택값과 의존성을 동기적으로 확보하고 게임 진행을 기다리게 하지 않는다.
  void recordSelectedQuiz() {
    try {
      final quizId = ref.read(selectedQuizProvider)?.id;
      if (quizId == null) return;
      final repository = ref.read(quizStatisticsRepositoryProvider);
      // 통계 API 전송
      unawaited(_send(repository, quizId));
    } catch (_) {
      // 통계 준비 실패도 게임 흐름에 전달하지 않는다.
    }
  }

  // 통계 API 전송: 완료 후 ref에 접근하지 않고 실패한 요청은 재시도하지 않는다.
  Future<void> _send(
    QuizStatisticsRepository repository,
    int quizId,
  ) async {
    try {
      // 통계 API 전송
      await repository.recordStart(quizId);
    } catch (_) {
      // 타임아웃은 서버 취소를 보장하지 않으므로 늦은 응답도 재전송하지 않는다.
    }
  }
}
