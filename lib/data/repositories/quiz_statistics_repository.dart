import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quiz_monster/core/exception/quiz_statistics_exception.dart';
import 'package:quiz_monster/data/data_sources/quiz_statistics_data_source.dart';

final quizStatisticsRepositoryProvider = Provider(
  (ref) => QuizStatisticsRepository(
    ref.read(quizStatisticsDataSourceProvider),
  ),
);

class QuizStatisticsRepository {
  final QuizStatisticsDataSource dataSource;

  QuizStatisticsRepository(this.dataSource);

  // 통계 API 전송
  Future<void> recordStart(int quizId) async {
    try {
      // 통계 API 전송
      await dataSource
          .recordStart(quizId)
          .timeout(const Duration(seconds: 10));
    } catch (_) {
      throw QuizStatisticsException();
    }
  }
}
