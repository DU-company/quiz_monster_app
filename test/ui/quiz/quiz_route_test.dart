import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quiz_monster/core/router/router_provider.dart';

void main() {
  testWidgets('잘못된 퀴즈 ID는 안내 화면으로 이동한다', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final router = container.read(goRouterProvider);
    addTearDown(router.dispose);
    router.go('/quiz-detail/wrong-id');

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('퀴즈 주소를 확인할 수 없습니다.'), findsOneWidget);
  });

  testWidgets('찜 목록 인자 없이 진입하면 안내 화면으로 이동한다', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final router = container.read(goRouterProvider);
    addTearDown(router.dispose);
    router.go('/wishlist');

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('찜 목록을 불러올 수 없습니다.'), findsOneWidget);
  });
}
