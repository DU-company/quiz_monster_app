import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:quiz_monster/core/router/router_provider.dart';
import 'package:quiz_monster/ui/common/layout/default_layout.dart';

GoRouter _router() => GoRouter(
  routes: [
    for (final path in ['/', '/next', '/replacement'])
      GoRoute(
        path: path,
        pageBuilder: (context, state) => buildSlidePage<void>(
          context,
          state,
          child: DefaultLayout(child: Center(child: Text(path))),
        ),
      ),
  ],
);

void main() {
  final positions = <TargetPlatform, Offset>{};
  testWidgets('두 플랫폼의 슬라이드는 같고 가장자리 뒤로가기는 iOS만 허용한다', (tester) async {
    for (final platform in [
      TargetPlatform.iOS,
      TargetPlatform.android,
    ]) {
      final router = _router();
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp.router(
            theme: ThemeData(platform: platform),
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();
      router.push('/next');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      positions[platform] = tester.getCenter(find.text('/next'));
      expect(
        positions[platform]!.dx,
        greaterThan(
          tester.view.physicalSize.width /
              tester.view.devicePixelRatio /
              2,
        ),
      );
      await tester.pumpAndSettle();
      final context = tester.element(find.text('/next'));
      if (platform == TargetPlatform.android) {
        await tester.dragFrom(
          const Offset(1, 200),
          const Offset(600, 0),
        );
        await tester.pumpAndSettle();
        expect(router.canPop(), isTrue);
        expect(find.text('/next'), findsOneWidget);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(router.canPop(), isFalse);
        expect(find.text('/'), findsOneWidget);
        await tester.pumpWidget(const SizedBox.shrink());
        continue;
      }
      expect(ModalRoute.of(context)!.popGestureEnabled, isTrue);

      // 짧게 끌었다 놓으면 현재 화면으로 되돌아가야 한다.
      var gesture = await tester.startGesture(const Offset(1, 200));
      await gesture.moveBy(const Offset(50, 0));
      await tester.pump(const Duration(milliseconds: 400));
      expect(ModalRoute.of(context)!.popGestureInProgress, isTrue);
      await gesture.up();
      await tester.pumpAndSettle();
      expect(router.canPop(), isTrue);
      expect(find.text('/next'), findsOneWidget);

      gesture = await tester.startGesture(const Offset(1, 200));
      await gesture.moveBy(const Offset(600, 0));
      await tester.pump(const Duration(milliseconds: 400));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(router.canPop(), isFalse);
      expect(find.text('/next'), findsNothing);
      expect(find.text('/'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    }
    expect(
      positions[TargetPlatform.iOS],
      positions[TargetPlatform.android],
    );
  });

  testWidgets('go로 다른 경로에 이동할 때 새 페이지 전환을 시작한다', (tester) async {
    final router = _router();
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(child: MaterialApp.router(routerConfig: router)),
    );
    await tester.pumpAndSettle();
    router.go('/replacement');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final route = ModalRoute.of(
      tester.element(find.text('/replacement')),
    )!;
    expect(route.animation!.value, greaterThan(0));
    expect(route.animation!.value, lessThan(1));
    await tester.pumpAndSettle();
    expect(find.text('/replacement'), findsOneWidget);
    expect(find.text('/'), findsNothing);
  });
}
