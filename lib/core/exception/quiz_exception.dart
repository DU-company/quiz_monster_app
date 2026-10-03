import 'package:quiz_monster/core/exception/custom_exception.dart';

class QuizException extends CustomException {
  QuizException() : super('퀴즈 목록을 불러올 수 없습니다.\n네트워크 연결을 확인해주세요!');
}

class QuizItemException extends CustomException {
  QuizItemException() : super('게임을 불러올 수 없습니다.\n잠시 후 다시 시도해주세요!');
}

class QuizDataException extends CustomException {
  QuizDataException(super.message);
}
