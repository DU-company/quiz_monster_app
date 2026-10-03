import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quiz_monster/ui/common/layout/setting_layout.dart';

void main() {
  testWidgets('선택한 퀴즈 없이 설정 경로에 진입하면 복귀 안내를 표시한다', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: SettingLayout(
            label: '설정',
            body: Text('설정 본문'),
            footer: Text('설정 버튼'),
          ),
        ),
      ),
    );

    expect(find.text('퀴즈를 다시 선택해 주세요.'), findsOneWidget);
    expect(find.text('홈으로'), findsOneWidget);
    expect(find.text('설정 본문'), findsNothing);
  });
}
