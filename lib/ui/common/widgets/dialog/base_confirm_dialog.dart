import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:quiz_monster/core/theme/theme_provider.dart';
import 'package:quiz_monster/ui/common/widgets/dialog/base_dialog.dart';

class BaseConfirmDialog extends ConsumerWidget {
  final String title;
  final String? content;
  final Widget? contentWidget;
  final String confirmLabel;
  final VoidCallback onTapConfirm;
  final String? cancelLabel;
  final VoidCallback? onTapCancel;

  const BaseConfirmDialog({
    super.key,
    required this.title,
    this.content,
    this.contentWidget,
    required this.confirmLabel,
    required this.onTapConfirm,
    this.cancelLabel,
    this.onTapCancel,
  }) : assert(content == null || contentWidget == null);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.read(themeServiceProvider);

    return BaseDialog(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          /// Title
          Text(
            title,
            style: theme.typo.headline6.copyWith(
              color: theme.color.secondary,
            ),
          ),
          const SizedBox(height: 6),

          /// Content
          if (content != null || contentWidget != null) ...[
            Flexible(
              child: SingleChildScrollView(
                child:
                    contentWidget ??
                    Text(
                      content!,
                      style: theme.typo.body2.copyWith(
                        color: theme.color.secondary,
                        fontSize: 16,
                        height: 1.25,
                        fontWeight: FontWeight.normal,
                      ),
                    ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          OverflowBar(
            overflowAlignment: OverflowBarAlignment.end,
            overflowSpacing: 4,
            alignment: MainAxisAlignment.end,
            spacing: 8,
            children: [
              if (cancelLabel != null)
                TextButton(
                  onPressed: onTapCancel ?? () => context.pop(),
                  style: TextButton.styleFrom(
                    foregroundColor: theme.color.subtext,
                  ),
                  child: Text(cancelLabel!),
                ),
              FilledButton(
                onPressed: onTapConfirm,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(112, 48),
                  backgroundColor: theme.color.secondary,
                  foregroundColor: theme.color.onSecondary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  confirmLabel,
                  style: theme.typo.subtitle1.copyWith(
                    color: theme.color.onSecondary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
