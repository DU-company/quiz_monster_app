import 'package:flutter_dotenv/flutter_dotenv.dart';

const CATEGORIES = [
  '맞추기',
  '라이어 게임',
  '이어말하기',
  '몸으로 말해요',
  '스피드 게임',
  '기타 게임',
];

// 원격 DB (기본): 로컬 DB 사용 시 아래 두 줄을 주석 처리합니다.
final SUPABASE_URL = dotenv.env['SUPABASE_URL']!;
final SUPABASE_API_KEY = dotenv.env['SUPABASE_API_KEY']!;

// 로컬 DB: 위 두 줄 대신 아래 두 줄의 주석을 해제합니다.
// Android 에뮬레이터 주소이며, iOS 시뮬레이터는 127.0.0.1을 사용합니다.
// 실제 기기는 같은 네트워크에 있는 Mac의 로컬 IP를 사용합니다.
// .env의 SUPABASE_LOCAL_API_KEY에는 로컬 Supabase의 anon 키를 넣습니다.
// final SUPABASE_URL = 'http://10.0.2.2:54321';
// final SUPABASE_API_KEY = dotenv.env['SUPABASE_LOCAL_API_KEY']!;
