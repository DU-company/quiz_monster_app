import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:quiz_monster/core/theme/theme_provider.dart';
import 'package:quiz_monster/data/models/quiz_detail_model.dart';
import 'package:quiz_monster/core/theme/responsive/layout.dart';

class QuizDetailCard extends ConsumerWidget {
  final QuizDetailModel detail;
  const QuizDetailCard({super.key, required this.detail});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.read(themeServiceProvider);

    return Container(
      decoration: BoxDecoration(
        color: theme.color.onPrimary.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(16),
      ),
      margin: EdgeInsets.symmetric(vertical: 16),
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 32),
      child: Column(
        children: [
          /// Level
          renderStars(),
          const SizedBox(height: 16),

          /// 이미지 링크가 있으면 이미지를 보여준다
          if (detail.imgUrl != null && detail.imgUrl!.isNotEmpty)
            Expanded(child: _ImageBox(imgUrl: detail.imgUrl!)),

          /// 질문이 있다면 질문을 UI에 보여준다
          if (detail.question != null)
            Expanded(child: _QuestionBox(question: detail.question!)),
        ],
      ),
    );
  }

  ///---------------------------------------------------------------------------
  Widget renderStars() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (index) {
        final isEmpty = index + 1 > detail.level;
        return Icon(
          size: 40,
          isEmpty ? Icons.star_border : Icons.star,
          color: isEmpty ? Colors.white : Colors.yellow,
        );
      }),
    );
  }
}

class _ImageBox extends StatelessWidget {
  final String imgUrl;
  const _ImageBox({super.key, required this.imgUrl});

  @override
  Widget build(BuildContext context) {
    return CachedNetworkImage(
      imageUrl: imgUrl,
      fadeOutDuration: Duration.zero,
      fadeInDuration: Duration.zero,
      placeholder: (context, url) {
        return SpinKitThreeBounce(color: Colors.white);
      },
    );
  }
}

class _QuestionBox extends ConsumerWidget {
  final String question;
  const _QuestionBox({super.key, required this.question});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.read(themeServiceProvider);

    return SizedBox(
      height: 180,
      child: Center(
        child: Text(
          'Q) $question',
          textAlign: TextAlign.center,
          style: theme.typo.headline6.copyWith(
            fontSize: context.layout(32, mobile: 24),
          ),
        ),
      ),
    );
  }
}
