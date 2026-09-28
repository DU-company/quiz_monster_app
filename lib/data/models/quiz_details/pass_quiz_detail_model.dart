import 'package:quiz_monster/data/entities/quiz_detail_entity.dart';
import 'package:quiz_monster/data/models/quiz_detail_model.dart';
import 'package:quiz_monster/data/models/quiz_model.dart';

class PassQuizDetailModel extends QuizDetailModel {
  const PassQuizDetailModel({
    required super.quiz,
    required super.id,
    required super.level,
    required super.answer,
  });

  factory PassQuizDetailModel.fromEntity(
    QuizModel quiz,
    QuizDetailEntity entity,
  ) {
    return PassQuizDetailModel(
      quiz: quiz,
      id: entity.id,
      level: entity.level,
      answer: entity.answer,
    );
  }
}
