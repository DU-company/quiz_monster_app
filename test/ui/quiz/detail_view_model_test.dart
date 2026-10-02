import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quiz_monster/core/provider/selected_quiz_provider.dart';
import 'package:quiz_monster/data/models/quiz_group.dart';
import 'package:quiz_monster/data/models/quiz_model.dart';
import 'package:quiz_monster/data/models/quiz_type.dart';
import 'package:quiz_monster/ui/quiz/detail/view_model/quiz_detail_state.dart';
import 'package:quiz_monster/ui/quiz/detail/view_model/quiz_detail_view_model.dart';

void main() {
  test('선택한 퀴즈 없이 상세 화면에 진입하면 오류 상태를 표시한다', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final provider = quizDetailViewModelProvider(1);
    final subscription = container.listen(provider, (_, _) {});
    addTearDown(subscription.close);

    await Future<void>.delayed(Duration.zero);

    expect(container.read(provider), isA<QuizDetailError>());
  });

  test('URL의 ID와 선택한 퀴즈 ID가 다르면 조회하지 않는다', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container
        .read(selectedQuizProvider.notifier)
        .state = const QuizModel(
      id: 1,
      title: '국기 보고 나라 맞추기',
      subTitle: '',
      desc: '',
      type: QuizType.image,
      group: QuizGroup.guess,
    );
    final provider = quizDetailViewModelProvider(2);
    final subscription = container.listen(provider, (_, _) {});
    addTearDown(subscription.close);

    await Future<void>.delayed(Duration.zero);

    expect(container.read(provider), isA<QuizDetailError>());
  });
}
