import 'package:flutter_test/flutter_test.dart';
import 'package:quiz_monster/core/exception/quiz_exception.dart';
import 'package:quiz_monster/data/data_sources/quiz_data_source.dart';
import 'package:quiz_monster/data/entities/quiz_entity.dart';
import 'package:quiz_monster/data/entities/quiz_detail_entity.dart';
import 'package:quiz_monster/data/models/quiz_detail_model.dart';
import 'package:quiz_monster/data/models/pagination_params.dart';
import 'package:quiz_monster/data/models/quiz_model.dart';
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

QuizModel quizFor(
  int id,
  QuizType type, {
  QuizGroup group = QuizGroup.guess,
}) => QuizModel.fromEntity(
  QuizEntity.fromJson({
    'id': id,
    'title': '서버 제목 $id',
    'subTitle': '부제',
    'desc': '설명',
    'game_type': type.name,
    'quiz_group': group.name,
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
    test('기존 카테고리 JSON과 찜 저장 ID를 유지한다', () {
      final quiz = quizFor(
        21,
        QuizType.pass,
        group: QuizGroup.charades,
      );
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
      final quiz = quizFor(1, QuizType.image);
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
        quizFor(2, QuizType.question),
        entity(question: '질문'),
      );
      expect(detail, isA<QuestionQuizDetailModel>());
      expect(detail.question, '질문');
    });

    test('패스와 라이어 문항은 단어 형식이다', () {
      final word = entity();
      expect(
        QuizDetailModel.fromEntity(
          quizFor(21, QuizType.pass, group: QuizGroup.charades),
          word,
        ),
        isA<PassQuizDetailModel>(),
      );
      expect(
        QuizDetailModel.fromEntity(quizFor(41, QuizType.liar), word),
        isA<LiarQuizDetailModel>(),
      );
    });

    test('필수 이미지와 질문이 비어 있으면 거부한다', () {
      expect(
        () => QuizDetailModel.fromEntity(
          quizFor(1, QuizType.image),
          entity(),
        ),
        throwsA(isA<QuizDataException>()),
      );
      expect(
        () => QuizDetailModel.fromEntity(
          quizFor(1, QuizType.image),
          entity(imgUrl: '  '),
        ),
        throwsA(isA<QuizDataException>()),
      );
      expect(
        () => QuizDetailModel.fromEntity(
          quizFor(2, QuizType.question),
          entity(),
        ),
        throwsA(isA<QuizDataException>()),
      );
      expect(
        () => QuizDetailModel.fromEntity(
          quizFor(2, QuizType.question),
          entity(question: '  '),
        ),
        throwsA(isA<QuizDataException>()),
      );
    });

    test('서버의 빈 정답을 변형 없이 보존한다', () {
      final pass = QuizDetailModel.fromEntity(
        quizFor(21, QuizType.pass, group: QuizGroup.charades),
        entity(answer: ''),
      );
      final liar = QuizDetailModel.fromEntity(
        quizFor(41, QuizType.liar),
        entity(answer: ''),
      );
      expect(pass.answer, '');
      expect(liar.answer, '');
    });
  });

  group('Repository 변환 경계', () {
    test('카테고리 Entity를 화면 Model로 변환한다', () async {
      final raw = QuizEntity.fromJson({
        'id': 101,
        'game_type': 'image',
        'quiz_group': 'guess',
        'title': '몸으로 말해요',
        'subTitle': '부제',
        'desc': '설명',
      });
      final result = await QuizRepository(
        FakeQuizDataSource([], quizzes: [raw]),
      ).getQuiz();
      expect(result.items.single.type, QuizType.image);
      expect(result.items.single.group, QuizGroup.guess);
    });

    test('누락·null·미지원 값에서도 ID로 분류하지 않는다', () {
      final fields = <String, dynamic>{
        'id': 1,
        'title': '게임',
        'subTitle': '',
        'desc': '',
      };
      for (final metadata in [
        <String, dynamic>{},
        {'game_type': null, 'quiz_group': null},
      ]) {
        final row = QuizEntity.fromJson({...fields, ...metadata});
        expect(row.gameType, isNull);
        expect(row.quizGroup, QuizGroup.other);
      }
      for (final value in ['future', '']) {
        final row = QuizEntity.fromJson({
          ...fields,
          'game_type': value,
          'quiz_group': value,
        });
        expect(row.gameType, isNull);
        expect(row.quizGroup, QuizGroup.other);
      }
      final mixed = QuizEntity.fromJson({
        ...fields,
        'quiz_group': 'future',
      });
      expect(mixed.gameType, isNull);
      expect(mixed.quizGroup, QuizGroup.other);
    });

    test('기존 ID라도 서버 유형을 우선하며 미지원 유형은 숨긴다', () async {
      final fields = {
        'id': 1,
        'title': '게임',
        'subTitle': '',
        'desc': '',
        'quiz_group': 'other',
      };
      final games = await QuizRepository(
        FakeQuizDataSource(
          [],
          quizzes: [
            QuizEntity.fromJson({...fields, 'game_type': 'reaction'}),
            QuizEntity.fromJson({
              ...fields,
              'id': 3,
              'game_type': 'future',
            }),
          ],
        ),
      ).getQuiz();
      expect(games.items.single.type, QuizType.reaction);
      expect(games.items.single.group, QuizGroup.other);
    });

    test('문항 Entity를 화면 Model로 변환하고 요청 인자를 보존한다', () async {
      final source = FakeQuizDataSource([
        entity(imgUrl: 'https://example.com/flag.png'),
      ]);
      final quiz = quizFor(1, QuizType.image);
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
        quiz: quizFor(61, QuizType.question),
        qid: 61,
        take: 30,
        level: 1,
      );
      expect(success.items, isEmpty);
    });

    test('파리 잡기는 서버 문항이 없어도 빈 목록으로 전달한다', () async {
      final quiz = quizFor(80, QuizType.fly);
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

    test('두 로컬 게임은 문항 RPC를 호출하지 않는다', () async {
      for (final (id, type) in [
        (80, QuizType.fly),
        (100, QuizType.reaction),
      ]) {
        final source = FakeQuizDataSource([entity()]);
        final result = await QuizRepository(source).getQuizDetails(
          quiz: quizFor(id, type),
          qid: id,
          take: 10,
          level: 1,
        );
        expect(result.items, isEmpty);
        expect(source.lastParams, isNull);
      }
    });

    test('필수 문항 필드가 없으면 QuizItemException으로 변환한다', () async {
      final source = FakeQuizDataSource([entity()]);
      expect(
        QuizRepository(source).getQuizDetails(
          quiz: quizFor(1, QuizType.image),
          qid: 1,
          take: 30,
          level: null,
        ),
        throwsA(isA<QuizItemException>()),
      );
    });
  });
}
