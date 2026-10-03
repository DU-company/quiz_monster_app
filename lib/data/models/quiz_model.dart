import 'package:quiz_monster/data/entities/quiz_entity.dart';
import 'package:quiz_monster/data/models/quiz_group.dart';
import 'package:quiz_monster/data/models/quiz_type.dart';

/// 카테고리 표시 정보와 해석된 진행 타입 및 목록 그룹을 담는 화면용 모델.
class QuizModel {
  final int id;
  final String title;
  final String desc;
  final String subTitle;
  final QuizType? type;
  final QuizGroup group;

  const QuizModel({
    required this.id,
    required this.title,
    required this.subTitle,
    required this.desc,
    required this.type,
    required this.group,
  });

  factory QuizModel.fromEntity(QuizEntity entity) => QuizModel(
    id: entity.id,
    title: entity.title,
    subTitle: entity.subTitle,
    desc: entity.desc,
    type: resolveQuizType(entity.id),
    group: resolveQuizGroup(entity.id),
  );
}
