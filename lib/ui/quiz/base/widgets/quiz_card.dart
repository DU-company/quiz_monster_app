import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:quiz_monster/core/theme/theme_provider.dart';
import 'package:quiz_monster/data/models/quiz_model.dart';

final randomNumberProvider = StateProvider.family<int, int>((
  ref,
  id,
) {
  final Random random = Random();
  return random.nextInt(5);
});

class QuizCard extends ConsumerWidget {
  final int id;
  final String title;
  final String subtitle;
  final String desc;
  final bool isLiked;
  final VoidCallback onLikePressed;
  const QuizCard({
    super.key,
    required this.id,
    required this.title,
    required this.subtitle,
    required this.desc,
    required this.isLiked,
    required this.onLikePressed,
  });

  factory QuizCard.fromModel({
    required QuizModel model,
    required bool isLiked,
    required VoidCallback onLikePressed,
  }) {
    return QuizCard(
      id: model.id,
      title: model.title,
      subtitle: model.subTitle,
      desc: model.desc,
      isLiked: isLiked,
      onLikePressed: onLikePressed,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.read(themeServiceProvider);
    final randomNumber = ref.watch(randomNumberProvider(id));
    return Container(
      height: 180,
      decoration: BoxDecoration(
        color: theme.color.primary,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Stack(
        children: [
          _ImageBox(randomNumber: randomNumber),
          _TextBox(title: title, subTitle: subtitle),
          _LikeButton(isLiked: isLiked, onPressed: onLikePressed),
        ],
      ),
    );
  }
}

class _ImageBox extends StatelessWidget {
  final int randomNumber;
  const _ImageBox({super.key, required this.randomNumber});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 0,
      top: 0,
      right: 0,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.asset(
          'assets/img/black$randomNumber.png',
          width: 150,
          fit: BoxFit.cover,
          alignment: Alignment.centerLeft,
        ),
      ),
    );
  }
}

class _TextBox extends ConsumerWidget {
  final String title;
  final String subTitle;
  const _TextBox({
    super.key,
    required this.title,
    required this.subTitle,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.read(themeServiceProvider);
    return Align(
      alignment: Alignment.bottomLeft,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.typo.headline6),
            const SizedBox(height: 4),
            Text(subTitle, style: theme.typo.subtitle2),
          ],
        ),
      ),
    );
  }
}

class _LikeButton extends ConsumerWidget {
  final VoidCallback onPressed;
  final bool isLiked;
  const _LikeButton({
    required this.onPressed,
    required this.isLiked,
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.read(themeServiceProvider);
    return Align(
      alignment: Alignment.topLeft,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: IconButton(
          style: IconButton.styleFrom(
            backgroundColor: theme.color.secondary,
            foregroundColor: theme.color.onSecondary,
          ),
          onPressed: onPressed,
          icon: Icon(
            isLiked
                ? CupertinoIcons.heart_fill
                : CupertinoIcons.heart,
            size: 24,
          ),
        ),
      ),
    );
  }
}
