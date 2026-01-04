import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:quiz_monster/ui/common/widgets/primary_button.dart';
import 'package:quiz_monster/core/service/supabase_provider.dart';
import 'package:quiz_monster/ui/common/layout/default_layout.dart';

import 'quiz_data.dart';

class TestScreen extends ConsumerWidget {
  static String routeName = 'test';
  const TestScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultLayout(
      backgroundColor: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('수파베이스 데이터베이스 삽입', textAlign: TextAlign.center),
          const SizedBox(height: 16),
          PrimaryButton(
            label: 'Insert',
            onPressed: () async {
              // final supabase = ref.read(supabaseProvider);
              // final list = ID16;
              // final quizItems = [...list];
              //
              // final response = await supabase
              //     .from('quiz_details')
              //     .insert(quizItems)
              //     .select(); // 선택적: 추가된 데이터 반환
              //
              // if (response.isNotEmpty) {
              //   print('퀴즈 항목들이 추가되었습니다: $response');
              // } else {
              //   print('퀴즈 추가 실패');
              // }
            },
          ),
        ],
      ),
    );
  }
}
