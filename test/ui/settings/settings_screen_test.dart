import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:quiz_monster/ui/settings/notification_state.dart';
import 'package:quiz_monster/ui/settings/notification_view_model.dart';
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

class _DeniedNotifications extends NotificationViewModel {
  final selections = <bool>[];

  @override
  NotificationState build() => const NotificationState(
    ready: true,
    permission: AuthorizationStatus.denied,
  );

  @override
  Future<void> setEnabled(bool enabled) async {
    selections.add(enabled);
    state = state.copyWith(enabled: enabled);
  }
}

void main() {
  testWidgets('거절 상태에서 취소하면 유지하고 확인해야 앱 설정을 연다', (tester) async {
    final notifier = _DeniedNotifications();
    var opened = 0;
    const channel = MethodChannel(
      'flutter.baseflow.com/permissions/methods',
    );
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (call) async {
        if (call.method == 'openAppSettings') opened++;
        return true;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          notificationViewModelProvider.overrideWith(() => notifier),
          appVersionProvider.overrideWith((ref) async => '1.0.0'),
        ],
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('알림 허용'));
    await tester.pumpAndSettle();
    expect(find.text('설정 열기'), findsNothing);
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(find.text('알림 권한이 필요해요'), findsOneWidget);
    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();
    expect(opened, 0);
    expect(notifier.selections, isEmpty);
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    await tester.tap(find.text('설정 열기'));
    await tester.pumpAndSettle();
    expect(opened, 1);
    expect(notifier.selections, [true]);
    expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
  });

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
    expect(find.text('문의사항'), findsOneWidget);
    await tester.tap(find.byType(BackButton));
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
    String? toastMessage;
    const toastChannel = MethodChannel('PonnamKarthik/fluttertoast');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      toastChannel,
      (call) async {
        toastMessage = (call.arguments as Map)['msg'] as String;
        return true;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(toastChannel, null),
    );
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
      tester.widget<Switch>(find.byType(Switch)).onChanged,
      isNull,
    );
    await tester.tap(find.text('문의사항'));
    await tester.pumpAndSettle();
    expect(copied, developerEmail);
    expect(toastMessage, '이메일을 복사했어요.');
  });
}
