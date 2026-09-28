// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'quiz_entity.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

QuizEntity _$QuizEntityFromJson(Map<String, dynamic> json) => QuizEntity(
      id: (json['id'] as num).toInt(),
      title: json['title'] as String,
      subTitle: json['subTitle'] as String,
      desc: json['desc'] as String,
      hasPass: json['hasPass'] as bool,
      isEtc: json['isEtc'] as bool,
    );

Map<String, dynamic> _$QuizEntityToJson(QuizEntity instance) =>
    <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'subTitle': instance.subTitle,
      'desc': instance.desc,
      'hasPass': instance.hasPass,
      'isEtc': instance.isEtc,
    };
