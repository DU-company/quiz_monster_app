import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quiz_monster/core/provider/selected_quiz_provider.dart';
import 'package:quiz_monster/data/repositories/quiz_repository.dart';
import 'package:quiz_monster/ui/quiz/detail/view_model/quiz_detail_state.dart';
import 'package:quiz_monster/ui/settings/level/level_provider.dart';

final quizDetailViewModelProvider = NotifierProvider.family
    .autoDispose((int qid) => QuizDetailViewModel(qid));

class QuizDetailViewModel extends Notifier<QuizDetailState> {
  final int qid;
  QuizDetailViewModel(this.qid);

  QuizRepository get repository => ref.read(quizRepositorProvider);
  @override
  QuizDetailState build() {
    Future.microtask(getQuizDetails);
    return QuizDetailLoading();
  }

  Future<void> getQuizDetails() async {
    try {
      if (!ref.mounted) {
        return;
      }
      state = QuizDetailLoading();

      final quiz = ref.read(selectedQuizProvider);
      if (quiz == null || quiz.id != qid) {
        state = QuizDetailError(
          '선택한 퀴즈를 확인할 수 없습니다.\n목록에서 다시 선택해 주세요.',
        );
        return;
      }
      final level = ref.read(levelProvider);
      final resp = await repository.getQuizDetails(
        quiz: quiz,
        qid: qid,
        take: 30,
        level: level,
      );
      if (!ref.mounted) {
        return;
      }
      state = resp;
    } catch (e) {
      if (ref.mounted) {
        state = QuizDetailError(e.toString());
      }
    }
  }
}
