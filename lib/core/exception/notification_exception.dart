import 'package:quiz_monster/core/exception/custom_exception.dart';

class NotificationException extends CustomException {
  NotificationException() : super('알림 설정을 저장하지 못했어요. 다시 시도해 주세요.');
}

class NotificationSetupException extends CustomException {
  NotificationSetupException() : super('알림 서비스 연결을 준비하고 있어요.');
}
