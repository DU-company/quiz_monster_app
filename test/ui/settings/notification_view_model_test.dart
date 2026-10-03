import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:quiz_monster/ui/settings/notification_listener.dart'
    as app;
import 'package:flutter_test/flutter_test.dart';
import 'package:quiz_monster/core/service/notification_service.dart';
import 'package:quiz_monster/data/data_sources/notification_data_source.dart';
import 'package:quiz_monster/ui/settings/notification_state.dart';
import 'package:quiz_monster/ui/settings/notification_view_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeService implements NotificationService {
  final tokenEvents = StreamController<String>.broadcast(sync: true);
  final messageEvents = StreamController<RemoteMessage>.broadcast(
    sync: true,
  );
  final openedEvents = StreamController<RemoteMessage>.broadcast(
    sync: true,
  );
  AuthorizationStatus status = AuthorizationStatus.authorized;
  String? currentToken = 'initial-token';
  bool failInitialization = false;
  int requests = 0;
  Completer<String?>? tokenResult;

  @override
  Future<void> initialize() async {
    if (failInitialization) throw StateError('Missing configuration');
  }

  @override
  Future<AuthorizationStatus> permission() async => status;
  @override
  Future<AuthorizationStatus> requestPermission() async {
    requests++;
    return status;
  }

  @override
  Future<String?> token() async =>
      tokenResult == null ? currentToken : await tokenResult!.future;
  @override
  Stream<String> get tokens => tokenEvents.stream;
  @override
  Stream<RemoteMessage> get messages => messageEvents.stream;
  @override
  Stream<RemoteMessage> get openedMessages => openedEvents.stream;
  @override
  Future<RemoteMessage?> initialMessage() async => null;
  @override
  Future<void> dispose() async {
    await tokenEvents.close();
    await messageEvents.close();
    await openedEvents.close();
  }
}

class FakeDataSource implements NotificationDataSource {
  final calls = <({bool enabled, String? token})>[];
  bool fail = false;
  Completer<void>? response;

  @override
  Future<void> synchronize({
    required bool enabled,
    String? token,
  }) async {
    calls.add((enabled: enabled, token: token));
    if (fail) throw StateError('Server unavailable');
    if (response != null) await response!.future;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeService service;
  late FakeDataSource source;
  late ProviderContainer container;
  late NotificationViewModel model;

  ProviderContainer newContainer() => ProviderContainer(
    overrides: [
      notificationServiceProvider.overrideWithValue(service),
      notificationDataSourceProvider.overrideWithValue(source),
    ],
  );

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    service = FakeService();
    source = FakeDataSource();
    container = newContainer();
    model = container.read(notificationViewModelProvider.notifier);
  });

  tearDown(() async {
    container.dispose();
    await service.dispose();
  });

  test(
    'initialization failure leaves notification feature unavailable',
    () async {
      service.failInitialization = true;
      await model.start();
      final state = container.read(notificationViewModelProvider);
      expect(state.ready, isFalse);
      expect(state.busy, isFalse);
      expect(state.sync, NotificationSync.unavailable);
      expect(source.calls, isEmpty);
    },
  );

  test(
    'token refresh wins over an older pending token lookup',
    () async {
      service.tokenResult = Completer<String?>();
      final starting = model.start();
      await Future<void>.delayed(Duration.zero);
      service.tokenEvents.add('new-token');
      service.tokenResult!.complete('old-token');
      await starting;
      await Future<void>.delayed(Duration.zero);
      expect(source.calls, isNotEmpty);
      expect(
        source.calls.every((call) => call.token == 'new-token'),
        isTrue,
      );
    },
  );

  test(
    'authorized startup registers token without permission prompt',
    () async {
      await model.start();
      expect(source.calls, [(enabled: true, token: 'initial-token')]);
      expect(service.requests, 0);
      expect(
        container.read(notificationViewModelProvider).switchValue,
        isTrue,
      );
      expect(
        container.read(notificationViewModelProvider).sync,
        NotificationSync.synced,
      );
    },
  );

  test(
    'denied permission is requested only once across app starts',
    () async {
      service.status = AuthorizationStatus.denied;
      await model.start();
      container.dispose();
      container = newContainer();
      model = container.read(notificationViewModelProvider.notifier);
      await model.start();
      expect(service.requests, 1);
      expect(source.calls.every((call) => !call.enabled), isTrue);
      expect(
        container.read(notificationViewModelProvider).switchValue,
        isFalse,
      );
    },
  );

  test(
    'missing APNs or FCM token stays pending until refresh',
    () async {
      service.currentToken = null;
      await model.start();
      expect(source.calls, isEmpty);
      expect(
        container.read(notificationViewModelProvider).sync,
        NotificationSync.pending,
      );
      expect(
        container.read(notificationViewModelProvider).busy,
        isFalse,
      );
      service.currentToken = 'available-token';
      await model.refresh();
      expect(source.calls.single.token, 'available-token');
      expect(
        container.read(notificationViewModelProvider).sync,
        NotificationSync.synced,
      );
    },
  );

  test(
    'server failure retains preference and retries on refresh',
    () async {
      source.fail = true;
      await model.start();
      expect(
        container.read(notificationViewModelProvider).sync,
        NotificationSync.failed,
      );
      expect(
        container.read(notificationViewModelProvider).enabled,
        isTrue,
      );
      source.fail = false;
      await model.refresh();
      expect(source.calls.length, 2);
      expect(
        container.read(notificationViewModelProvider).sync,
        NotificationSync.synced,
      );
    },
  );

  test(
    'OFF persists and token rotation cannot reactivate notifications',
    () async {
      await model.start();
      await model.setEnabled(false);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('notifications_enabled'), isFalse);
      service.tokenEvents.add('rotated-token');
      await model.refresh();
      expect(
        source.calls.skip(1).every((call) => !call.enabled),
        isTrue,
      );
      container.dispose();
      container = newContainer();
      model = container.read(notificationViewModelProvider.notifier);
      await model.start();
      expect(
        container.read(notificationViewModelProvider).switchValue,
        isFalse,
      );
      expect(source.calls.last.enabled, isFalse);
    },
  );

  test('OFF wins over an ON operation waiting for a token', () async {
    SharedPreferences.setMockInitialValues({
      'notifications_enabled': false,
    });
    await model.start();
    service.tokenResult = Completer<String?>();
    final enabling = model.setEnabled(true);
    await Future<void>.delayed(Duration.zero);
    final disabling = model.setEnabled(false);
    service.tokenResult!.complete('late-token');
    await Future.wait([enabling, disabling]);
    expect(source.calls.every((call) => !call.enabled), isTrue);
    expect(
      container.read(notificationViewModelProvider).enabled,
      isFalse,
    );
    expect(
      container.read(notificationViewModelProvider).busy,
      isFalse,
    );
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('notifications_enabled'), isFalse);
  });

  test(
    'OFF preference saves while an ON server request is pending',
    () async {
      SharedPreferences.setMockInitialValues({
        'notifications_enabled': false,
      });
      await model.start();
      source.response = Completer<void>();
      final enabling = model.setEnabled(true);
      await Future<void>.delayed(Duration.zero);
      expect(source.calls.last.enabled, isTrue);
      final disabling = model.setEnabled(false);
      await Future<void>.delayed(Duration.zero);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('notifications_enabled'), isFalse);
      source.response!.complete();
      await Future.wait([enabling, disabling]);
      expect(source.calls.last.enabled, isFalse);
      expect(
        container.read(notificationViewModelProvider).switchValue,
        isFalse,
      );
    },
  );

  test(
    'foreground messages are deduplicated and suppressed while OFF',
    () async {
      await model.start();
      const first = RemoteMessage(
        messageId: 'same',
        data: {'body': 'first'},
      );
      const duplicate = RemoteMessage(
        messageId: 'same',
        data: {'body': 'second'},
      );
      service.messageEvents.add(first);
      service.messageEvents.add(duplicate);
      expect(
        container
            .read(notificationViewModelProvider)
            .foregroundMessage,
        same(first),
      );
      await model.setEnabled(false);
      service.messageEvents.add(
        const RemoteMessage(messageId: 'disabled'),
      );
      expect(
        container
            .read(notificationViewModelProvider)
            .foregroundMessage,
        same(first),
      );
    },
  );

  test(
    'disposing provider container cancels all message subscriptions',
    () async {
      await model.start();
      expect(service.tokenEvents.hasListener, isTrue);
      expect(service.messageEvents.hasListener, isTrue);
      expect(service.openedEvents.hasListener, isTrue);
      container.dispose();
      container = ProviderContainer();
      expect(service.tokenEvents.hasListener, isFalse);
      expect(service.messageEvents.hasListener, isFalse);
      expect(service.openedEvents.hasListener, isFalse);
    },
  );
  test(
    'refresh deactivates server registration after OS permission revocation',
    () async {
      await model.start();
      service.status = AuthorizationStatus.denied;
      await model.refresh();
      expect(source.calls.last.enabled, isFalse);
      expect(
        container.read(notificationViewModelProvider).switchValue,
        isFalse,
      );
      expect(service.requests, 0);
    },
  );

  test(
    'refresh retrieves current token when rotation stream was missed',
    () async {
      await model.start();
      service.currentToken = 'newest-token';
      await model.refresh();
      expect(source.calls.last, (
        enabled: true,
        token: 'newest-token',
      ));
    },
  );

  Widget listenerApp() {
    final messengerKey = GlobalKey<ScaffoldMessengerState>();
    return UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        scaffoldMessengerKey: messengerKey,
        builder: (context, child) => app.NotificationListener(
          messengerKey: messengerKey,
          child: child!,
        ),
        home: const Scaffold(body: Text('기존 퀴즈 화면')),
      ),
    );
  }

  testWidgets(
    'initialization failure preserves existing app rendering',
    (tester) async {
      service.failInitialization = true;
      tester.binding.handleAppLifecycleStateChanged(
        AppLifecycleState.resumed,
      );
      await tester.runAsync(() => model.start());
      await tester.pumpWidget(listenerApp());
      await tester.pumpAndSettle();
      expect(find.text('기존 퀴즈 화면'), findsOneWidget);
      expect(tester.takeException(), isNull);
      expect(
        container.read(notificationViewModelProvider).sync,
        NotificationSync.unavailable,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'foreground notification shows title and body without navigation',
    (tester) async {
      tester.binding.handleAppLifecycleStateChanged(
        AppLifecycleState.resumed,
      );
      await tester.runAsync(() => model.start());
      await tester.pumpWidget(listenerApp());
      await tester.pumpAndSettle();
      expect(
        container.read(notificationViewModelProvider).ready,
        isTrue,
      );
      const message = RemoteMessage(
        messageId: 'foreground-test',
        notification: RemoteNotification(
          title: '오늘의 퀴즈',
          body: '새로운 문제를 풀어보세요',
        ),
      );
      service.messageEvents.add(message);
      await tester.pump();
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text('오늘의 퀴즈\n새로운 문제를 풀어보세요'), findsOneWidget);
      service.openedEvents.add(
        const RemoteMessage(messageId: 'tap-test'),
      );
      await tester.pump();
      expect(find.text('기존 퀴즈 화면'), findsOneWidget);
      expect(find.byType(Scaffold), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
