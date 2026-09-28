import 'package:quiz_monster/core/exception/quiz_exception.dart';
import 'package:quiz_monster/data/entities/quiz_detail_entity.dart';
import 'package:quiz_monster/data/models/quiz_model.dart';
import 'package:quiz_monster/data/models/quiz_type.dart';
import 'package:quiz_monster/data/models/quiz_details/image_quiz_detail_model.dart';
import 'package:quiz_monster/data/models/quiz_details/liar_quiz_detail_model.dart';
import 'package:quiz_monster/data/models/quiz_details/pass_quiz_detail_model.dart';
import 'package:quiz_monster/data/models/quiz_details/question_quiz_detail_model.dart';

export 'quiz_details/image_quiz_detail_model.dart';
export 'quiz_details/liar_quiz_detail_model.dart';
export 'quiz_details/pass_quiz_detail_model.dart';
export 'quiz_details/question_quiz_detail_model.dart';

/// 서버 문항을 화면에서 사용하는 형식별 문항의 공통 값으로 변환한다.
abstract class QuizDetailModel {
  final QuizModel quiz;
  final String id;
  final int level;
  final String answer;

  const QuizDetailModel({
    required this.quiz,
    required this.id,
    required this.level,
    required this.answer,
  });

  String? get imgUrl => null;
  String? get question => null;

  factory QuizDetailModel.fromEntity(
    QuizModel quiz,
    QuizDetailEntity entity,
  ) {
    return switch (quiz.type) {
      QuizType.image => ImageQuizDetailModel.fromEntity(quiz, entity),
      QuizType.question => QuestionQuizDetailModel.fromEntity(
        quiz,
        entity,
      ),
      QuizType.pass => PassQuizDetailModel.fromEntity(quiz, entity),
      QuizType.liar => LiarQuizDetailModel.fromEntity(quiz, entity),
      _ => throw QuizDataException('지원하지 않는 문항 형식: ${quiz.id}'),
    };
  }
}
