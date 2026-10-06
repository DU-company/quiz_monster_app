import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quiz_monster/core/theme/responsive/layout.dart';
import 'package:quiz_monster/core/theme/theme_provider.dart';

class LevelButton extends ConsumerWidget {
  final int? level;
  final void Function(int) onLevelChanged;
  final VoidCallback onTapNoLevel;

  const LevelButton({
    super.key,
    required this.level,
    required this.onLevelChanged,
    required this.onTapNoLevel,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.read(themeServiceProvider);

    return Container(
      height: context.layout(300, mobile: 200),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(3, (index) {
              final bool isEmptyStar =
                  (level == null || index + 1 > level!);
              return GestureDetector(
                onTap: () => onLevelChanged(index),
                child: Icon(
                  isEmptyStar ? Icons.star_border : Icons.star,
                  size: 56,
                  color: isEmptyStar
                      ? theme.color.onHintContainer
                      : theme.color.tertiary,
                ),
              );
            }),
          ),
          TextButton(
            onPressed: onTapNoLevel,
            style: TextButton.styleFrom(
              foregroundColor: theme.color.primary,
            ),
            child: Text(
              '난이도 상관없이 플레이',
              style: theme.typo.subtitle1.copyWith(
                color: theme.color.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
