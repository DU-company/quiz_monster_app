import 'package:flutter_test/flutter_test.dart';
import 'package:quiz_monster/core/exception/quiz_exception.dart';
import 'package:quiz_monster/data/data_sources/quiz_data_source.dart';
import 'package:quiz_monster/data/entities/quiz_entity.dart';
import 'package:quiz_monster/data/entities/quiz_detail_entity.dart';
import 'package:quiz_monster/data/models/quiz_detail_model.dart';
import 'package:quiz_monster/data/models/quiz_group.dart';
import 'package:quiz_monster/data/models/pagination_params.dart';
import 'package:quiz_monster/data/models/quiz_model.dart';
import 'package:quiz_monster/data/models/quiz_type.dart';
import 'package:quiz_monster/data/repositories/quiz_repository.dart';

class FakeQuizDataSource implements QuizDataSource {
  FakeQuizDataSource(this.details, {this.quizzes = const []});

  final List<QuizDetailEntity> details;
  final List<QuizEntity> quizzes;
  PaginationParams? lastParams;

  @override
  Future<List<QuizDetailEntity>> fetchQuizDetails(
    PaginationParams params,
  ) async {
    lastParams = params;
    return details;
  }

  @override
  Future<List<QuizEntity>> fetchQuiz() async => quizzes;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('사용하지 않는 DataSource API');
}

QuizModel quizFor(int id, {String? title}) => QuizModel.fromEntity(
  QuizEntity.fromJson({
    'id': id,
    'title': title ?? '서버 제목 $id',
    'subTitle': '부제',
    'desc': '설명',
    'hasPass': const {21, 22, 23, 29, 31, 32, 40}.contains(id),
    'isEtc': const {61, 70, 80, 100}.contains(id),
  }),
);

QuizDetailEntity entity({
  String? imgUrl,
  String? question,
  String answer = '정답',
}) => QuizDetailEntity.fromJson({
  'id': 'detail-1',
  'level': 2,
  'imgUrl': imgUrl,
  'question': question,
  'answer': answer,
});

void main() {
  group('카테고리 형식', () {
    final idsByFormat = <QuizType, List<int>>{
      QuizType.image: [1, 3, 10],
      QuizType.question: [2, 11, 12, 13, 14, 15, 16, 17, 61, 70],
      QuizType.pass: [21, 22, 23, 29, 31, 32, 40],
      QuizType.liar: [41, 42, 43, 44, 45, 46, 59],
      QuizType.fly: [80],
      QuizType.reaction: [100],
    };

    test('확인된 29개 ID를 서버 제목과 무관하게 분류한다', () {
      expect(
        idsByFormat.values.expand((ids) => ids).toSet().length,
        29,
      );
      for (final entry in idsByFormat.entries) {
        for (final id in entry.value) {
          expect(quizFor(id).type, entry.key, reason: '카테고리 ID $id');
          expect(
            quizFor(id, title: '변경된 제목').type,
            entry.key,
            reason: '제목이 바뀐 카테고리 ID $id',
          );
        }
      }
    });

    test('확인된 카테고리를 기존 목록 탭에 배정한다', () {
      final idsByGroup = <QuizGroup, List<int>>{
        QuizGroup.guess: [1, 2, 3, 10],
        QuizGroup.liar: [41, 42, 43, 44, 45, 46, 59],
        QuizGroup.continuation: [11, 12, 13, 14, 15, 16, 17],
        QuizGroup.charades: [21, 22, 23, 29],
        QuizGroup.speed: [31, 32, 40],
        QuizGroup.other: [61, 70, 80, 100],
      };
      for (final entry in idsByGroup.entries) {
        for (final id in entry.value) {
          expect(quizFor(id).group, entry.key, reason: '카테고리 ID $id');
        }
      }
    });

    test('알 수 없는 ID는 형식 정보가 없다', () {
      expect(quizFor(999).type, isNull);
    });

    test('기존 카테고리 JSON과 찜 저장 ID를 유지한다', () {
      final quiz = quizFor(21);
      expect(quiz.id, 21);
      expect(quiz.id.toString(), '21');
      expect(quiz.title, '서버 제목 21');
      expect(quiz.subTitle, '부제');
      expect(quiz.desc, '설명');
      expect(quiz.type, QuizType.pass);
      expect(quiz.group, QuizGroup.charades);
    });
  });

  group('문항 변환', () {
    test('이미지 문항은 ID와 원본 값을 보존한다', () {
      final quiz = quizFor(1);
      final detail = QuizDetailModel.fromEntity(
        quiz,
        entity(imgUrl: 'https://example.com/flag.png'),
      );
      expect(detail, isA<ImageQuizDetailModel>());
      expect(detail.id, 'detail-1');
      expect(detail.level, 2);
      expect(detail.answer, '정답');
      expect(detail.imgUrl, 'https://example.com/flag.png');
    });

    test('질문 문항은 질문을 보존한다', () {
      final detail = QuizDetailModel.fromEntity(
        quizFor(2),
        entity(question: '질문'),
      );
      expect(detail, isA<QuestionQuizDetailModel>());
      expect(detail.question, '질문');
    });

    test('패스와 라이어 문항은 단어 형식이다', () {
      final word = entity();
      expect(
        QuizDetailModel.fromEntity(quizFor(21), word),
        isA<PassQuizDetailModel>(),
      );
      expect(
        QuizDetailModel.fromEntity(quizFor(41), word),
        isA<LiarQuizDetailModel>(),
      );
    });

    test('필수 이미지와 질문이 비어 있으면 거부한다', () {
      expect(
        () => QuizDetailModel.fromEntity(quizFor(1), entity()),
        throwsA(isA<QuizDataException>()),
      );
      expect(
        () => QuizDetailModel.fromEntity(
          quizFor(1),
          entity(imgUrl: '  '),
        ),
        throwsA(isA<QuizDataException>()),
      );
      expect(
        () => QuizDetailModel.fromEntity(quizFor(2), entity()),
        throwsA(isA<QuizDataException>()),
      );
      expect(
        () => QuizDetailModel.fromEntity(
          quizFor(2),
          entity(question: '  '),
        ),
        throwsA(isA<QuizDataException>()),
      );
    });

    test('서버의 빈 정답을 변형 없이 보존한다', () {
      final pass = QuizDetailModel.fromEntity(
        quizFor(21),
        entity(answer: ''),
      );
      final liar = QuizDetailModel.fromEntity(
        quizFor(41),
        entity(answer: ''),
      );
      expect(pass.answer, '');
      expect(liar.answer, '');
    });
  });

  group('Repository 변환 경계', () {
    test('카테고리 Entity를 화면 Model로 변환한다', () async {
      final raw = QuizEntity.fromJson({
        'id': 21,
        'title': '몸으로 말해요',
        'subTitle': '부제',
        'desc': '설명',
        'hasPass': true,
        'isEtc': false,
      });
      final result = await QuizRepository(
        FakeQuizDataSource([], quizzes: [raw]),
      ).getQuiz();
      expect(result.items.single.type, QuizType.pass);
      expect(result.items.single.group, QuizGroup.charades);
    });

    test('문항 Entity를 화면 Model로 변환하고 요청 인자를 보존한다', () async {
      final source = FakeQuizDataSource([
        entity(imgUrl: 'https://example.com/flag.png'),
      ]);
      final quiz = quizFor(1);
      final success = await QuizRepository(
        source,
      ).getQuizDetails(quiz: quiz, qid: quiz.id, take: 30, level: 2);

      expect(identical(success.quiz, quiz), isTrue);
      expect(success.items.single, isA<ImageQuizDetailModel>());
      expect(success.items.single.id, 'detail-1');
      expect(source.lastParams?.p_qid, 1);
      expect(source.lastParams?.p_take, 30);
      expect(source.lastParams?.p_level, 2);
    });

    test('질문형 RPC의 빈 응답을 성공 상태로 보존한다', () async {
      final source = FakeQuizDataSource([]);
      final success = await QuizRepository(source).getQuizDetails(
        quiz: quizFor(61),
        qid: 61,
        take: 30,
        level: 1,
      );
      expect(success.items, isEmpty);
    });

    test('파리 잡기는 서버 문항이 없어도 빈 목록으로 전달한다', () async {
      final quiz = quizFor(80);
      final success = await QuizRepository(FakeQuizDataSource([]))
          .getQuizDetails(
            quiz: quiz,
            qid: quiz.id,
            take: 30,
            level: null,
          );
      expect(success.quiz, same(quiz));
      expect(success.items, isEmpty);
    });

    test('파리 잡기에 서버 문항이 오면 오류로 변환한다', () async {
      final quiz = quizFor(80);
      expect(
        QuizRepository(FakeQuizDataSource([entity()])).getQuizDetails(
          quiz: quiz,
          qid: quiz.id,
          take: 30,
          level: null,
        ),
        throwsA(isA<QuizItemException>()),
      );
    });

    test('필수 문항 필드가 없으면 QuizItemException으로 변환한다', () async {
      final source = FakeQuizDataSource([entity()]);
      expect(
        QuizRepository(source).getQuizDetails(
          quiz: quizFor(1),
          qid: 1,
          take: 30,
          level: null,
        ),
        throwsA(isA<QuizItemException>()),
      );
    });
  });
}
