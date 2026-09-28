import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quiz_monster/core/exception/quiz_exception.dart';
import 'package:quiz_monster/data/data_sources/quiz_data_source.dart';
import 'package:quiz_monster/data/models/pagination_params.dart';
import 'package:quiz_monster/data/models/pagination_state.dart';
import 'package:quiz_monster/data/models/quiz_detail_model.dart';
import 'package:quiz_monster/data/models/quiz_model.dart';
import 'package:quiz_monster/data/models/quiz_type.dart';
import 'package:quiz_monster/ui/quiz/detail/view_model/quiz_detail_state.dart';

final quizRepositorProvider = Provider((ref) {
  final quizDataSource = ref.read(quizDataSourceProvider);
  return QuizRepository(quizDataSource);
});

class QuizRepository {
  final QuizDataSource quizDataSource;

  QuizRepository(this.quizDataSource);

  Future<PaginationSuccess<QuizModel>> getQuiz() async {
    try {
      final resp = await quizDataSource.fetchQuiz();
      final items = resp.map(QuizModel.fromEntity).toList();
      return PaginationSuccess(items: items);
    } catch (e) {
      throw QuizException();
    }
  }

  Future<QuizDetailSuccess> getQuizDetails({
    required QuizModel quiz,
    required int qid,
    required int take,
    required int? level,
  }) async {
    try {
      final params = PaginationParams(
        p_qid: qid,
        p_take: take,
        p_level: level,
      );
      final entities = await quizDataSource.fetchQuizDetails(params);
      final type = quiz.type;
      if (type == null) {
        throw QuizDataException('지원하지 않는 퀴즈: ${quiz.id}');
      }
      if (type == QuizType.fly || type == QuizType.reaction) {
        if (entities.isNotEmpty) {
          throw QuizDataException(
            '파리/반응속도 게임에 서버 문항이 있습니다: ${quiz.id}',
          );
        }
        return QuizDetailSuccess(quiz: quiz, items: const []);
      }
      final items = entities
          .map((entity) => QuizDetailModel.fromEntity(quiz, entity))
          .toList();
      return QuizDetailSuccess(quiz: quiz, items: items);
    } catch (e) {
      throw QuizItemException();
    }
  }
}
