import 'package:json_annotation/json_annotation.dart';

part 'quiz_entity.g.dart';

enum QuizType { image, question, pass, liar, fly, reaction }

enum QuizGroup { guess, liar, continuation, charades, speed, other }

@JsonSerializable()
class QuizEntity {
  final int id;
  final String title;
  final String subTitle;
  final String desc;

  @JsonKey(
    name: 'game_type',
    unknownEnumValue: JsonKey.nullForUndefinedEnumValue,
  )
  final QuizType? gameType;
  @JsonKey(
    name: 'quiz_group',
    defaultValue: QuizGroup.other,
    unknownEnumValue: QuizGroup.other,
  )
  final QuizGroup quizGroup;

  const QuizEntity({
    this.gameType,
    required this.quizGroup,
    required this.id,
    required this.title,
    required this.subTitle,
    required this.desc,
  });

  factory QuizEntity.fromJson(Map<String, dynamic> json) =>
      _$QuizEntityFromJson(json);
}
