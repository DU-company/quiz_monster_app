import 'package:json_annotation/json_annotation.dart';

part 'quiz_entity.g.dart';

@JsonSerializable()
class QuizEntity {
  final int id;
  final String title;
  final String subTitle;
  final String desc;
  final bool hasPass;
  final bool isEtc;

  const QuizEntity({
    required this.id,
    required this.title,
    required this.subTitle,
    required this.desc,
    required this.hasPass,
    required this.isEtc,
  });

  factory QuizEntity.fromJson(Map<String, dynamic> json) =>
      _$QuizEntityFromJson(json);
}
