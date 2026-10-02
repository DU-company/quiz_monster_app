import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quiz_monster/data/models/quiz_group.dart';
import 'package:quiz_monster/data/models/quiz_model.dart';
import 'package:quiz_monster/data/models/quiz_type.dart';
import 'package:quiz_monster/ui/quiz/detail/quiz_detail_screen.dart';
import 'package:quiz_monster/ui/quiz/detail/view_model/quiz_detail_state.dart';
import 'package:quiz_monster/ui/quiz/detail/view_model/quiz_detail_view_model.dart';

class _EmptyDetailViewModel extends QuizDetailViewModel {
  _EmptyDetailViewModel(super.qid);

  @override
  QuizDetailState build() => QuizDetailSuccess(
    quiz: const QuizModel(
      id: 61,
      title: '훈민정음',
      subTitle: '',
      desc: '',
      type: QuizType.question,
      group: QuizGroup.other,
    ),
    items: const [],
  );
}

void main() {
  testWidgets('빈 문항 응답은 문항 화면 대신 안내를 표시한다', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          quizDetailViewModelProvider(
            61,
          ).overrideWith(() => _EmptyDetailViewModel(61)),
        ],
        child: const MaterialApp(home: QuizDetailScreen(61)),
      ),
    );

    expect(
      find.textContaining('선택한 조건에 맞는 문항이 없습니다.'),
      findsOneWidget,
    );
  });
}
