import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:go_router/go_router.dart';
import 'package:quiz_monster/ui/quiz/base/widgets/quiz_app_bar.dart';
import 'package:quiz_monster/ui/settings/settings_screen.dart';
import 'package:quiz_monster/ui/wishlist/wishlist_screen.dart';
import 'package:quiz_monster/core/router/router_provider.dart';
import 'package:quiz_monster/ui/settings/settings_view_model.dart';

void main() {
  testWidgets('홈 설정 버튼에서 진입하고 복귀한 뒤 찜 버튼도 사용할 수 있다', (tester) async {
    final fonts = FontLoader('Roboto')
      ..addFont(rootBundle.load('assets/fonts/Roboto-Medium.ttf'));
    await fonts.load();
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => Scaffold(
            body: CustomScrollView(slivers: [QuizAppBar(const [])]),
          ),
        ),
        GoRoute(
          path: '/settings',
          name: SettingsScreen.routeName,
          builder: (_, _) => const SettingsScreen(),
        ),
        GoRoute(
          path: '/wishlist',
          name: WishlistScreen.routeName,
          builder: (_, state) =>
              Text('찜 목록: ${(state.extra as List).length}'),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appVersionProvider.overrideWith((ref) async => '1.2.3'),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('환경설정'));
    await tester.pumpAndSettle();
    expect(find.text('개발자 이메일'), findsOneWidget);
    await tester.tap(find.byTooltip('뒤로'));
    await tester.pumpAndSettle();
    expect(find.text('QUIZ MONSTER'), findsOneWidget);
    await tester.tap(find.byType(IconButton).first);
    await tester.pumpAndSettle();
    expect(find.text('찜 목록: 0'), findsOneWidget);
  });

  testWidgets('환경설정 경로에서 빌드 버전과 이메일을 표시하고 복사한다', (tester) async {
    PackageInfo.setMockInitialValues(
      appName: '퀴즈몬스터',
      packageName: 'test',
      version: '2.3.4',
      buildNumber: '20304',
      buildSignature: '',
    );
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final router = container.read(goRouterProvider);
    addTearDown(router.dispose);
    router.go('/settings');
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null),
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('환경설정'), findsOneWidget);
    expect(find.text('2.3.4'), findsOneWidget);
    expect(find.text(developerEmail), findsOneWidget);
    expect(
      tester
          .widget<SwitchListTile>(find.byType(SwitchListTile))
          .onChanged,
      isNull,
    );
    await tester.tap(find.byTooltip('이메일 복사'));
    await tester.pumpAndSettle();
    expect(copied, developerEmail);
    expect(find.text('이메일을 복사했어요.'), findsOneWidget);
  });
}
