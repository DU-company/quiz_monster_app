import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:quiz_monster/core/exception/quiz_statistics_exception.dart';
import 'package:quiz_monster/data/data_sources/quiz_statistics_data_source.dart';
import 'package:quiz_monster/data/repositories/quiz_statistics_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  final url = Platform.environment['QUIZ_STATISTICS_TEST_URL'];
  final anonKey =
      Platform.environment['QUIZ_STATISTICS_TEST_ANON_KEY'];
  final adminKey =
      Platform.environment['QUIZ_STATISTICS_TEST_ADMIN_KEY'];
  test(
    'isolated HTTP records starts and preserves dashboard read permissions',
    () async {
      final uri = Uri.parse(url!);
      expect(uri.host, anyOf('127.0.0.1', 'localhost'));
      expect(uri.port, 55439);
      final proxy = await HttpServer.bind(
        InternetAddress.loopbackIPv4,
        0,
      );
      final transport = HttpClient();
      proxy.listen((request) async {
        try {
          final target = uri.replace(
            path: request.uri.path.replaceFirst('/rest/v1', ''),
            query: request.uri.query,
          );
          final forwarded = await transport.openUrl(
            request.method,
            target,
          );
          request.headers.forEach((name, values) {
            if (name != HttpHeaders.hostHeader) {
              forwarded.headers.set(name, values);
            }
          });
          await forwarded.addStream(request);
          final response = await forwarded.close();
          request.response.statusCode = response.statusCode;
          response.headers.forEach(request.response.headers.set);
          await response.pipe(request.response);
        } catch (_) {
          request.response.statusCode = 502;
          await request.response.close();
        }
      });
      final proxyUrl = 'http://127.0.0.1:${proxy.port}';
      final anon = SupabaseClient(proxyUrl, anonKey!);
      final admin = SupabaseClient(proxyUrl, adminKey!);
      addTearDown(() async {
        await anon.dispose();
        await admin.dispose();
        await proxy.close(force: true);
        transport.close(force: true);
      });
      final repository = QuizStatisticsRepository(
        SupabaseQuizStatisticsDataSource(anon),
      );
      final before = await admin
          .from('quiz_start_daily_counts')
          .select('quiz_id,stat_date,start_count')
          .eq('quiz_id', 80);
      final totalBefore = before.fold<int>(
        0,
        (sum, row) => sum + (row['start_count'] as int),
      );
      final started = DateTime.now().toUtc().add(
        const Duration(hours: 9),
      );
      // 통계 API 전송
      await repository.recordStart(80);
      final finished = DateTime.now().toUtc().add(
        const Duration(hours: 9),
      );
      String date(DateTime value) =>
          value.toIso8601String().substring(0, 10);
      // 웹과 같은 필드·기간 필터·정렬·페이지 범위를 사용한다.
      final after = await admin
          .from('quiz_start_daily_counts')
          .select('quiz_id,stat_date,start_count')
          .gte('stat_date', date(started))
          .lte('stat_date', date(finished))
          .order('quiz_id')
          .order('stat_date')
          .range(0, 999);
      expect(after.where((row) => row['quiz_id'] == 80), isNotEmpty);
      final allAfter = await admin
          .from('quiz_start_daily_counts')
          .select('quiz_id,stat_date,start_count')
          .eq('quiz_id', 80);
      expect(
        allAfter.fold<int>(
          0,
          (sum, row) => sum + (row['start_count'] as int),
        ),
        totalBefore + 1,
      );
      await expectLater(
        anon.from('quiz_start_daily_counts').select(),
        throwsA(isA<PostgrestException>()),
      );
      await expectLater(
        anon.from('quiz_start_daily_counts').insert({
          'quiz_id': 80,
          'stat_date': date(finished),
          'start_count': 999,
        }),
        throwsA(isA<PostgrestException>()),
      );
      // 통계 API 전송
      await expectLater(
        repository.recordStart(-1),
        throwsA(isA<QuizStatisticsException>()),
      );
    },
    skip: url == null || anonKey == null || adminKey == null
        ? '격리 로컬 PostgREST 환경변수가 없으면 실행하지 않습니다.'
        : false,
  );
}
