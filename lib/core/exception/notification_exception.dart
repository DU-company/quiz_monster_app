import 'package:quiz_monster/core/exception/custom_exception.dart';

class NotificationException extends CustomException {
  NotificationException() : super('알림 설정을 저장하지 못했어요. 다시 시도해 주세요.');
}

class NotificationSetupException extends CustomException {
  NotificationSetupException() : super('알림 서비스 연결을 준비하고 있어요.');
}

class NotificationAuthException extends CustomException {
  NotificationAuthException()
    : super('알림 등록 정보를 확인하지 못했어요. 개발자에게 문의해 주세요.');
}

class NotificationConflictException extends CustomException {
  NotificationConflictException()
    : super('다른 알림 설정이 먼저 반영됐어요. 알림을 다시 선택해 주세요.');
}

class NotificationTokenConflictException extends CustomException {
  NotificationTokenConflictException()
    : super('알림 등록이 중복됐어요. 새 토큰으로 다시 등록해 주세요.');
}
