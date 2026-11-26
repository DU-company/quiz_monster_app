// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'quiz_entity.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

QuizEntity _$QuizEntityFromJson(Map<String, dynamic> json) => QuizEntity(
      gameType: $enumDecodeNullable(_$QuizTypeEnumMap, json['game_type'],
          unknownValue: JsonKey.nullForUndefinedEnumValue),
      quizGroup: $enumDecodeNullable(_$QuizGroupEnumMap, json['quiz_group'],
              unknownValue: QuizGroup.other) ??
          QuizGroup.other,
      id: (json['id'] as num).toInt(),
      title: json['title'] as String,
      subTitle: json['subTitle'] as String,
      desc: json['desc'] as String,
    );

Map<String, dynamic> _$QuizEntityToJson(QuizEntity instance) =>
    <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'subTitle': instance.subTitle,
      'desc': instance.desc,
      'game_type': _$QuizTypeEnumMap[instance.gameType],
      'quiz_group': _$QuizGroupEnumMap[instance.quizGroup]!,
    };

const _$QuizTypeEnumMap = {
  QuizType.image: 'image',
  QuizType.question: 'question',
  QuizType.pass: 'pass',
  QuizType.liar: 'liar',
  QuizType.fly: 'fly',
  QuizType.reaction: 'reaction',
};

const _$QuizGroupEnumMap = {
  QuizGroup.guess: 'guess',
  QuizGroup.liar: 'liar',
  QuizGroup.continuation: 'continuation',
  QuizGroup.charades: 'charades',
  QuizGroup.speed: 'speed',
  QuizGroup.other: 'other',
};
