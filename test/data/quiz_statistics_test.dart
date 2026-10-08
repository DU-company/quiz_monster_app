import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quiz_monster/core/exception/quiz_statistics_exception.dart';
import 'package:quiz_monster/core/provider/quiz_start_statistics_provider.dart';
import 'package:quiz_monster/core/provider/selected_quiz_provider.dart';
import 'package:quiz_monster/data/data_sources/quiz_statistics_data_source.dart';
import 'package:quiz_monster/data/models/quiz_model.dart';
import 'package:quiz_monster/data/models/quiz_group.dart';
import 'package:quiz_monster/data/models/quiz_type.dart';
import 'package:quiz_monster/data/repositories/quiz_statistics_repository.dart';

class FakeStatisticsSource implements QuizStatisticsDataSource {
  final ids = <int>[];
  Future<void> Function()? response;
  @override
  Future<void> recordStart(int quizId) {
    ids.add(quizId);
    return response?.call() ?? Future.value();
  }
}

QuizModel quiz(int id) => QuizModel(
  id: id,
  title: 'test',
  subTitle: '',
  desc: '',
  type: resolveQuizType(id),
  group: resolveQuizGroup(id),
);

void main() {
  late FakeStatisticsSource source;
  late ProviderContainer container;
  setUp(() {
    source = FakeStatisticsSource();
    container = ProviderContainer(
      overrides: [
        quizStatisticsDataSourceProvider.overrideWithValue(source),
      ],
    );
  });
  tearDown(() => container.dispose());
  void start() => container
      .read(quizStartStatisticsProvider.notifier)
      .recordSelectedQuiz();

  test('repository forwards quiz ID once', () async {
    await QuizStatisticsRepository(source).recordStart(80);
    expect(source.ids, [80]);
  });
  for (final synchronous in [true, false]) {
    test(
      'repository converts error (synchronous=$synchronous)',
      () async {
        source.response = () {
          if (synchronous) throw StateError('offline');
          return Future.error(StateError('offline'));
        };
        await expectLater(
          QuizStatisticsRepository(source).recordStart(100),
          throwsA(isA<QuizStatisticsException>()),
        );
        expect(source.ids, [100]);
      },
    );
    testWidgets('provider absorbs error (synchronous=$synchronous)', (
      tester,
    ) async {
      source.response = () {
        if (synchronous) throw StateError('offline');
        return Future.error(StateError('offline'));
      };
      container.read(selectedQuizProvider.notifier).state = quiz(80);
      start();
      await tester.pump();
      expect(source.ids, [80]);
    });
  }
  test('unselected quiz skips repository initialization', () {
    final isolated = ProviderContainer(
      overrides: [
        quizStatisticsRepositoryProvider.overrideWith(
          (ref) => throw StateError('must not initialize'),
        ),
      ],
    );
    addTearDown(isolated.dispose);
    isolated
        .read(quizStartStatisticsProvider.notifier)
        .recordSelectedQuiz();
    expect(source.ids, isEmpty);
  });
  test('provider initialization errors do not escape', () {
    final isolated = ProviderContainer(
      overrides: [
        quizStatisticsRepositoryProvider.overrideWith(
          (ref) => throw StateError('unavailable'),
        ),
      ],
    );
    addTearDown(isolated.dispose);
    isolated.read(selectedQuizProvider.notifier).state = quiz(80);
    expect(
      () => isolated
          .read(quizStartStatisticsProvider.notifier)
          .recordSelectedQuiz(),
      returnsNormally,
    );
  });
  testWidgets(
    'pending request returns immediately and captures original selection',
    (tester) async {
      final pending = Completer<void>();
      source.response = () => pending.future;
      container.read(selectedQuizProvider.notifier).state = quiz(80);
      start();
      container.read(selectedQuizProvider.notifier).state = quiz(100);
      expect(pending.isCompleted, isFalse);
      expect(source.ids, [80]);
      pending.complete();
      await tester.pump();
      start();
      await tester.pump();
      expect(source.ids, [80, 100]);
    },
  );
  testWidgets('repository times out without retrying', (
    tester,
  ) async {
    final pending = Completer<void>();
    source.response = () => pending.future;
    final assertion = expectLater(
      QuizStatisticsRepository(source).recordStart(80),
      throwsA(isA<QuizStatisticsException>()),
    );
    await tester.pump(const Duration(seconds: 11));
    await assertion;
    pending.complete();
    await tester.pump();
    expect(source.ids, [80]);
  });
  for (final lateError in [true, false]) {
    for (final timeout in [true, false]) {
      testWidgets(
        'response after disposal (error=$lateError, timeout=$timeout)',
        (tester) async {
          final pending = Completer<void>();
          source.response = () => pending.future;
          final isolated = ProviderContainer(
            overrides: [
              quizStatisticsDataSourceProvider.overrideWithValue(
                source,
              ),
            ],
          );
          isolated.read(selectedQuizProvider.notifier).state = quiz(
            100,
          );
          isolated
              .read(quizStartStatisticsProvider.notifier)
              .recordSelectedQuiz();
          isolated.dispose();
          if (timeout) await tester.pump(const Duration(seconds: 11));
          if (lateError) {
            pending.completeError(StateError('late network failure'));
          } else {
            pending.complete();
          }
          await tester.pump();
          expect(source.ids, [100]);
        },
      );
    }
  }
}
