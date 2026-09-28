import 'package:quiz_monster/core/exception/quiz_exception.dart';
import 'package:quiz_monster/data/entities/quiz_detail_entity.dart';
import 'package:quiz_monster/data/models/quiz_detail_model.dart';
import 'package:quiz_monster/data/models/quiz_model.dart';

class ImageQuizDetailModel extends QuizDetailModel {
  @override
  final String imgUrl;

  const ImageQuizDetailModel({
    required super.quiz,
    required super.id,
    required super.level,
    required super.answer,
    required this.imgUrl,
  });

  factory ImageQuizDetailModel.fromEntity(
    QuizModel quiz,
    QuizDetailEntity entity,
  ) {
    final imgUrl = entity.imgUrl;
    if (imgUrl == null || imgUrl.trim().isEmpty) {
      throw QuizDataException('이미지 문항에 imgUrl이 없습니다: ${entity.id}');
    }
    return ImageQuizDetailModel(
      quiz: quiz,
      id: entity.id,
      level: entity.level,
      answer: entity.answer,
      imgUrl: imgUrl,
    );
  }
}
