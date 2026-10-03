import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quiz_monster/ui/quiz/etc/reaction/view_model/reaction_view_model.dart';

void main() {
  testWidgets('결과 화면에서 다시 시작하면 첫 라운드가 다시 진행된다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ProviderScope(
          child: Consumer(
            builder: (context, ref, _) {
              final state = ref.watch(reactionViewModelProvider);
              return Text('${state.currentStep}:${state.isGreen}');
            },
          ),
        ),
      ),
    );

    final container = ProviderScope.containerOf(
      tester.element(find.byType(Consumer)),
    );
    expect(find.text('1:false'), findsOneWidget);

    await tester.pump(const Duration(seconds: 5));
    expect(find.text('1:true'), findsOneWidget);

    final viewModel = container.read(
      reactionViewModelProvider.notifier,
    );
    viewModel.onTapCircle();
    expect(
      container.read(reactionViewModelProvider).resultList,
      hasLength(1),
    );

    viewModel.resetScreen();
    await tester.pump();
    expect(find.text('1:false'), findsOneWidget);
    expect(
      container.read(reactionViewModelProvider).resultList,
      isEmpty,
    );

    await tester.pump(const Duration(seconds: 5));
    expect(find.text('1:true'), findsOneWidget);
    expect(
      container.read(reactionViewModelProvider).startTime,
      isNotNull,
    );
  });
}
