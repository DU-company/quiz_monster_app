import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quiz_monster/core/service/supabase_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final quizStatisticsDataSourceProvider =
    Provider<QuizStatisticsDataSource>(
      (ref) => SupabaseQuizStatisticsDataSource(
        ref.read(supabaseProvider),
      ),
    );

abstract class QuizStatisticsDataSource {
  // 통계 API 전송
  Future<void> recordStart(int quizId);
}

class SupabaseQuizStatisticsDataSource
    implements QuizStatisticsDataSource {
  final SupabaseClient client;

  SupabaseQuizStatisticsDataSource(this.client);

  // 통계 API 전송
  @override
  Future<void> recordStart(int quizId) async {
    // 통계 API 전송
    await client.rpc(
      'record_quiz_start',
      params: {'p_quiz_id': quizId},
    );
  }
}
