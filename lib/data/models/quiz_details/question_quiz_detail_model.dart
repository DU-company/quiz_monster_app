import 'package:quiz_monster/core/exception/quiz_exception.dart';
import 'package:quiz_monster/data/entities/quiz_detail_entity.dart';
import 'package:quiz_monster/data/models/quiz_detail_model.dart';
import 'package:quiz_monster/data/models/quiz_model.dart';

class QuestionQuizDetailModel extends QuizDetailModel {
  @override
  final String question;

  const QuestionQuizDetailModel({
    required super.quiz,
    required super.id,
    required super.level,
    required super.answer,
    required this.question,
  });

  factory QuestionQuizDetailModel.fromEntity(
    QuizModel quiz,
    QuizDetailEntity entity,
  ) {
    final question = entity.question;
    if (question == null || question.trim().isEmpty) {
      throw QuizDataException('질문 문항에 question이 없습니다: ${entity.id}');
    }
    return QuestionQuizDetailModel(
      quiz: quiz,
      id: entity.id,
      level: entity.level,
      answer: entity.answer,
      question: question,
    );
  }
}
