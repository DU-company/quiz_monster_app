import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quiz_monster/ui/common/widgets/primary_button.dart';
import 'package:quiz_monster/core/theme/theme_provider.dart';

class CountSelector extends ConsumerWidget {
  final int count;
  final int minimum;
  final int maximum;
  final VoidCallback onTapIncrease;
  final VoidCallback onTapDecrease;
  const CountSelector({
    super.key,
    required this.count,
    required this.minimum,
    required this.maximum,
    required this.onTapIncrease,
    required this.onTapDecrease,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.read(themeServiceProvider);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        PrimaryButton(
          label: '−',
          onPressed: count <= minimum ? null : onTapDecrease,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0),
          child: Text('$count', style: theme.typo.headline1),
        ),
        PrimaryButton(
          label: '+',
          onPressed: count >= maximum ? null : onTapIncrease,
        ),
      ],
    );
  }
}
