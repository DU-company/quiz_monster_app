import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:go_router/go_router.dart';
import 'package:quiz_monster/core/const/data.dart';
import 'package:quiz_monster/core/theme/theme_provider.dart';
import 'package:quiz_monster/ui/quiz/pass/pass_quiz_screen.dart';
import 'package:quiz_monster/ui/common/layout/setting_layout.dart';
import 'package:quiz_monster/ui/quiz/pass/view_model/pass_view_model.dart';
import '../../common/widgets/primary_button.dart';
import '../time/set_time_screen.dart';
import '../level/level_provider.dart';

class SetPassScreen extends ConsumerWidget {
  static String routeName = 'pass';
  const SetPassScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(passViewModelProvider);
    final viewModel = ref.read(passViewModelProvider.notifier);

    return SettingLayout(
      label: '패스 횟수를 선택해 주세요\n(1~9회 선택 가능)',
      body: _PassKeyboard(
        passCount: state.passCount,
        onTapNumber: (number) => viewModel.onPassChanged(number),
        noPassPressed: () => viewModel.onTapNoPass(context),
      ),
      footer: PrimaryButton(
        label: 'NEXT',
        onPressed: state.passCount == 0
            ? null
            : () => viewModel.onTapNext(context),
      ),
    );
  }
}

class _PassKeyboard extends ConsumerWidget {
  final int passCount;
  final void Function(int number) onTapNumber;
  final void Function() noPassPressed;
  const _PassKeyboard({
    super.key,
    required this.passCount,
    required this.onTapNumber,
    required this.noPassPressed,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.read(themeServiceProvider);
    final buttons = [1, 2, 3, 4, 5, 6, 7, 8, 9];

    return Column(
      children: [
        Container(
          padding: EdgeInsets.symmetric(vertical: 24, horizontal: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Text(
                'PASS : $passCount 회',
                textAlign: TextAlign.center,
                style: theme.typo.headline5.copyWith(
                  color: theme.color.primary,
                ),
              ),
              const SizedBox(height: 16),
              GridView.builder(
                physics: NeverScrollableScrollPhysics(),
                shrinkWrap: true,
                itemCount: buttons.length,
                gridDelegate:
                    SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      childAspectRatio: 3,
                    ),
                itemBuilder: (context, index) {
                  return Material(
                    color: Colors.white,
                    child: InkWell(
                      onTap: () => onTapNumber(index + 1),
                      child: Center(
                        child: Text(
                          buttons[index].toString(),
                          style: theme.typo.headline6.copyWith(
                            color: theme.color.secondary,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: noPassPressed,
                style: TextButton.styleFrom(
                  foregroundColor: theme.color.primary,
                ),
                child: Text(
                  '패스 없이 게임하기',
                  style: theme.typo.subtitle1.copyWith(
                    color: theme.color.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          "긴박한 순간! 광고를 시청하면\n패스를 한 번 추가할 수 있습니다.",
          textAlign: TextAlign.center,
          style: theme.typo.subtitle2,
        ),
      ],
    );
  }
}
