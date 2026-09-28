import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quiz_monster/core/service/supabase_provider.dart';
import 'package:quiz_monster/data/entities/quiz_detail_entity.dart';
import 'package:quiz_monster/data/entities/quiz_entity.dart';
import 'package:quiz_monster/data/models/pagination_params.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final quizDataSourceProvider = Provider((ref) {
  final supabase = ref.read(supabaseProvider);
  return QuizDataSource(supabase);
});

class QuizDataSource {
  final SupabaseClient supabase;

  QuizDataSource(this.supabase);

  Future<List<QuizEntity>> fetchQuiz() async {
    final resp = await supabase
        .from('quiz')
        .select()
        .order('id', ascending: true);
    return resp.map(QuizEntity.fromJson).toList();
  }

  Future<List<QuizDetailEntity>> fetchQuizDetails(
    PaginationParams params,
  ) async {
    final List<dynamic> resp;
    if (params.p_level == null) {
      /// 난이도 상관 없이 랜덤
      resp = await supabase.rpc(
        'random_pagination',
        params: params.toJson(),
      );
    } else {
      /// 난이도가 존재한다. ( 1 2 3 )
      resp = await supabase.rpc(
        'random_pagination_with_level',
        params: params.toJson(),
      );
    }
    return resp
        .map(
          (item) =>
              QuizDetailEntity.fromJson(item as Map<String, dynamic>),
        )
        .toList();
  }
}
