import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:quiz_monster/core/provider/selected_quiz_provider.dart';
import 'package:quiz_monster/data/data_sources/quiz_statistics_data_source.dart';
import 'package:quiz_monster/ui/ad/ad_finished_provider.dart';
import 'package:quiz_monster/ui/ad/interstitial_ad_view_model.dart';
import 'package:quiz_monster/ui/common/widgets/dialog/base_confirm_dialog.dart';
import 'package:quiz_monster/ui/quiz/base/widgets/start_quiz_dialog.dart';
import 'package:quiz_monster/ui/quiz/etc/reaction/reaction_rate_screen.dart';
import 'package:quiz_monster/ui/quiz/etc/reaction/view_model/reaction_view_model.dart';
import 'package:quiz_monster/ui/quiz/etc/reaction/widgets/replay_dialog.dart';
import 'package:quiz_monster/ui/quiz_settings/player/set_player_view_model.dart';
import 'package:quiz_monster/ui/quiz_settings/time/set_time_view_model.dart';
import 'package:quiz_monster/ui/quiz_settings/time/time_count_screen.dart';
import '../../data/quiz_statistics_test.dart'
    show FakeStatisticsSource, quiz;

class NoAdViewModel extends InterstitialAdViewModel {
  int starts = 0;
  bool deferCompletion = false;
  bool failLoading = false;
  @override
  Future<InterstitialAd?> build() async {
    if (failLoading) throw StateError('ad load failed');
    return null;
  }

  @override
  void showAd() {
    starts++;
    if (!deferCompletion) super.showAd();
  }
}

void main() {
  late FakeStatisticsSource source;
  late NoAdViewModel ad;
  late ProviderContainer container;
  setUp(() {
    source = FakeStatisticsSource();
    ad = NoAdViewModel();
    container = ProviderContainer(
      overrides: [
        quizStatisticsDataSourceProvider.overrideWithValue(source),
        interstitialAdViewModelProvider.overrideWith(() => ad),
      ],
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('PonnamKarthik/fluttertoast'),
          (_) async => true,
        );
  });
  tearDown(() => container.dispose());

  for (final id in [1, 2, 21, 80]) {
    testWidgets(
      'time quiz $id counts valid start once, skips invalid time',
      (tester) async {
        container.read(selectedQuizProvider.notifier).state = quiz(
          id,
        );
        final subscription = container.listen(
          timeViewModelProvider,
          (_, _) {},
        );
        addTearDown(subscription.close);
        final vm = container.read(timeViewModelProvider.notifier);
        vm.onTimeChanged(const Duration(seconds: 2));
        vm.onTapStart();
        expect(source.ids, isEmpty);
        vm.onTimeChanged(const Duration(seconds: 3));
        vm.onTapStart();
        vm.onTapStart();
        await tester.pump();
        expect(source.ids, [id]);
        expect(ad.starts, 1);
        expect(container.read(adFinishedProvider), true);
        vm.prepareStart();
        container.read(timeViewModelProvider.notifier).onTapStart();
        await tester.pump();
        expect(source.ids, [id, id]);
      },
    );
  }

  for (final failure in [false, true]) {
    testWidgets(
      'statistics pending/error does not delay start (failure=$failure)',
      (tester) async {
        final subscription = container.listen(
          timeViewModelProvider,
          (_, _) {},
        );
        addTearDown(subscription.close);
        final pending = Completer<void>();
        source.response = () => failure
            ? Future.error(StateError('offline'))
            : pending.future;
        container.read(selectedQuizProvider.notifier).state = quiz(
          80,
        );
        container.read(timeViewModelProvider.notifier).onTapStart();
        expect(ad.starts, 1);
        expect(container.read(adFinishedProvider), true);
        if (!failure) pending.complete();
        await tester.pump();
        expect(source.ids, [80]);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('ad load failure still counts and proceeds once', (
    tester,
  ) async {
    ad.failLoading = true;
    await expectLater(
      container.read(interstitialAdViewModelProvider.future),
      throwsStateError,
    );
    container.read(selectedQuizProvider.notifier).state = quiz(80);
    final subscription = container.listen(
      timeViewModelProvider,
      (_, _) {},
    );
    addTearDown(subscription.close);
    final vm = container.read(timeViewModelProvider.notifier);
    vm.onTapStart();
    vm.onTapStart();
    await tester.pump();
    expect(source.ids, [80]);
    expect(ad.starts, 1);
    expect(container.read(adFinishedProvider), true);
  });

  testWidgets(
    'liar new settings attempt counts again and preserves player selection',
    (tester) async {
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      final context = tester.element(find.byType(SizedBox));
      container.read(selectedQuizProvider.notifier).state = quiz(41);
      final vm = container.read(playerViewModelProvider.notifier);
      vm.increasePlayer();
      vm.onStart(context);
      vm.onStart(context);
      expect(source.ids, [41]);
      vm.prepareStart();
      expect(container.read(playerViewModelProvider), 4);
      vm.onStart(context);
      await tester.pump();
      expect(source.ids, [41, 41]);
      expect(ad.starts, 2);
    },
  );

  Future<void> mount(WidgetTester tester, Widget child) async {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => Scaffold(body: child),
        ),
        GoRoute(
          path: '/countdown',
          name: TimeCountScreen.routeName,
          builder: (_, _) => const Scaffold(body: Text('countdown')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump();
  }

  testWidgets(
    'reaction initial cancel is zero, confirm and duplicate callback count once',
    (tester) async {
      await mount(
        tester,
        Builder(
          builder: (context) => TextButton(
            onPressed: () => showDialog(
              context: context,
              builder: (_) => StartQuizDialog(model: quiz(100)),
            ),
            child: const Text('open'),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('닫기'));
      await tester.pumpAndSettle();
      expect(source.ids, isEmpty);
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      final confirm = tester
          .widget<BaseConfirmDialog>(find.byType(BaseConfirmDialog))
          .onTapConfirm;
      confirm();
      confirm();
      await tester.pumpAndSettle();
      expect(source.ids, [100]);
      expect(find.text('countdown'), findsOneWidget);
      expect(ad.starts, 0);
    },
  );

  testWidgets(
    'reaction replay cancellation, duplicate confirmation and measurement steps',
    (tester) async {
      ad.deferCompletion = true;
      container.read(selectedQuizProvider.notifier).state = quiz(100);
      await tester.binding.setSurfaceSize(const Size(400, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await mount(tester, const ReactionRateScreen());
      final vm = container.read(reactionViewModelProvider.notifier);
      Future<void> finishGame() async {
        for (var i = 0; i < 5; i++) {
          await tester.pump(const Duration(seconds: 5));
          vm.onTapCircle();
          if (i < 4) vm.onTapNext();
        }
        await tester.pump();
      }

      await finishGame();
      await tester.tap(find.text('다시 시작'));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text('뒤로가기'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(source.ids, isEmpty);
      await tester.tap(find.text('다시 시작'));
      await tester.pump(const Duration(milliseconds: 400));
      final confirm = tester
          .widget<RecationReplayDialog>(
            find.byType(RecationReplayDialog),
          )
          .onTapReplay;
      confirm();
      confirm();
      await tester.pump(const Duration(milliseconds: 400));
      expect(source.ids, [100]);
      expect(ad.starts, 1);
      await tester.tap(find.text('다시 시작'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(RecationReplayDialog), findsNothing);
      expect(source.ids, [100]);
      container.read(adFinishedProvider.notifier).onFinish();
      await tester.pump();
      expect(
        container.read(reactionViewModelProvider).currentStep,
        1,
      );
      vm.onTapCircle();
      vm.onTapNext();
      expect(source.ids, [100]);
      vm.resetScreen();
      await finishGame();
      await tester.tap(find.text('다시 시작'));
      await tester.pump(const Duration(milliseconds: 400));
      tester
          .widget<RecationReplayDialog>(
            find.byType(RecationReplayDialog),
          )
          .onTapReplay();
      await tester.pump(const Duration(milliseconds: 400));
      expect(source.ids, [100, 100]);
      await tester.pumpWidget(const SizedBox());
      container.dispose();
    },
  );
}
