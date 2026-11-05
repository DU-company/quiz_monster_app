import 'package:quiz_monster/core/exception/custom_exception.dart';

class QuizStatisticsException extends CustomException {
  QuizStatisticsException() : super('퀴즈 시작 통계를 전송하지 못했습니다.');
}
