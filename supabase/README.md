# 알림 토큰 저장소

이 디렉터리는 앱의 알림 기능만 관리한다. 기존 대시보드 마이그레이션과 `.supabase-local/`의 로컬 데이터는 옮기거나 삭제하지 않는다. 기존 알림 배포 상태는 NOTIFICATION_SETUP.md를 참고한다. 이번 예약 확장은 아직 원격에 적용하지 않았다.

## 데이터 계약

`push_tokens`는 다음 6개 필드만 사용한다.

| 필드            | 용도                                        |
| --------------- | ------------------------------------------- |
| installation_id | 설치별 UUID 기본키                          |
| credential_hash | 설치 비밀값의 SHA-256 해시                  |
| fcm_token       | 현재 FCM 주소, 없으면 null                  |
| enabled         | 앱 선택 ON과 OS 권한 허용을 모두 만족하는지 |
| revision        | 늦게 도착한 이전 요청을 거절하는 요청 번호  |
| updated_at      | 서버가 마지막으로 반영한 시각               |

OS 권한과 사용자 선택은 앱이 따로 보관하고 서버에는 합쳐진 enabled를 보낸다. platform, 생성 시각, 토큰 교체 시각, 별도 무효화 시각은 저장하지 않는다. `push_token_rate_limits`는 전역·설치별 요청 제한을 여러 API 인스턴스가 공유하기 위한 보조 테이블이다.

설치 ID와 난수 비밀값, 요청 내용과 번호를 하나의 OS 보안 저장 항목으로 먼저 보관한다. Android에서는 해당 저장 파일만 백업/기기 이전에서 제외하고 iOS에서는 this-device Keychain을 사용한다. iOS 삭제·재설치 시 Keychain이 남을 수 있다. 저장소 오류를 새 설치 생성으로 숨기지 않는다. 사용자 선택은 SharedPreferences에도 보관하지만 보안 저장소의 최신 선택이 우선한다.

## API

`POST /functions/v1/notification-installations`, Content-Type: application/json, `X-Installation-Secret`: 설치별 32바이트 난수의 64자리 소문자 hex.

- 등록 body: action=register, installation_id. 새 설치는 비활성 revision 0으로 생성한다.
- 동기화 body: action=sync, installation_id, revision, enabled, fcm_token. OFF이면 token은 null이어도 된다.
- 성공 응답: revision, enabled. 토큰·비밀값·해시는 응답에 포함하지 않는다.
- 같은 번호와 같은 내용은 재전송 가능하다. 낮은 번호나 같은 번호의 다른 내용은 409다. 타 설치의 토큰을 빼앗지 않고 token_conflict를 반환한다.
- 401은 설치 인증 오류, 409는 revision/token 충돌, 429는 빈도 제한, 503은 서버 일시 실패다. 앱은 선택을 보관하고 다음 실행/복귀에서 다시 동기화한다. 충돌은 새 선택 또는 사용자의 재등록 동작으로 복구한다.

요청은 최대 8 KiB, 토큰은 최대 4096자다. 현재 분당 전역 register 30회, sync 1000회, 설치별 60회로 제한한다. 앱이 매 동기화 전 register를 호출하므로 register 한도는 기존 설치의 동기화에도 적용된다. 실제 사용량에 맞는 한도 조정은 운영 적용 전에 필요하다. 전역 한도는 익명 등록 남용을 제한하지만 공격자가 전체 한도를 소진하는 문제까지 해결하지는 않는다.

앱의 테이블 직접 접근과 RPC 실행은 금지한다. Edge Function에서만 서버 키로 등록 RPC를 호출하며 매번 설치 비밀값을 검증한다. 등록 함수는 verify_jwt=false이고 설치 비밀값을 검증한다. 별도 발송 함수는 서버 전용 발송 키로 인증한다. 서버 키는 앱에 넣지 않는다.

## 발송 담당 계약

서버 역할로 `notification_active_tokens()`를 호출하면 enabled=true이면서 토큰이 있는 설치 ID/토큰만 반환한다. 발송 직전에 조회하고, 발송에 실패한 **현재 토큰**만 `notification_invalidate_token(p_installation_id, p_fcm_token)`으로 무효화한다. 이미 새 토큰으로 바뀌었으면 false이고 새 값은 유지된다.

무효화는 토큰을 null, enabled를 false로 만들고 revision은 유지한다. 기존 요청 재전송은 충돌로 거절된다. 더 높은 번호의 새 요청은 같은 토큰도 다시 등록할 수 있으므로 영구 실패 토큰은 클라이언트가 새 FCM 토큰을 발급받도록 해야 한다. Phase 5에서 발송 큐와 서버 발송 API를 추가했다. 오프라인 OFF는 서버에 동기화될 때까지 발송을 막을 수 없다.

## 적용·복구

1. 관리 대상 DB와 기존 migration 이력을 확인하고, 기존 스키마를 복사한 **격리 로컬 DB**에 먼저 적용한다. 이 디렉터리만으로 기존 퀴즈 DB 전체를 재구축할 수 없다.
2. `migrations/20261003010000_notification_installations.sql`을 적용한다. 기존 퀴즈 객체는 수정하지 않는다. 로컬 데이터를 지우는 reset은 사용하지 않는다.
3. `tests/notification_installations_test.sql`을 실행한다. 테스트는 트랜잭션을 rollback하여 테스트 행을 남기지 않는다.
4. Edge Function에 테스트 DB의 SUPABASE_URL/SUPABASE_SERVICE_ROLE_KEY를 주입해 구동한다. 키와 토큰은 명령 로그에 출력하지 않는다.
5. 필요하면 `rollback/notification_installations.sql`로 이번에 추가한 객체만 제거한다. 알림 데이터는 삭제되므로 적용 대상과 백업을 확인한다. migration 이력 도구를 사용했다면 이력도 해당 도구의 절차에 맞게 관리한다.
6. 원격 적용은 대상 프로젝트를 확인하고 별도로 실행한다. migration 적용 후 Edge Function을 배포하고 테스트 설치의 등록/OFF를 확인한다.

검증 명령 예시(환경변수는 로컬 테스트 환경으로 미리 설정):

```sh
psql "$NOTIFICATION_TEST_DB_URL" -v ON_ERROR_STOP=1 -f supabase/migrations/20261003010000_notification_installations.sql
psql "$NOTIFICATION_TEST_DB_URL" -v ON_ERROR_STOP=1 -f supabase/tests/notification_installations_test.sql
deno test supabase/functions/notification-installations/handler_test.ts
flutter test test/data test/ui
flutter test test/data/notification_api_integration_test.dart
```

실제 API 통합 테스트는 NOTIFICATION_TEST_URL과 NOTIFICATION_TEST_ANON_KEY가 필요하며 미설정이면 skip된다. 이 테스트는 가짜 토큰의 테스트 설치를 생성하므로 격리 DB에만 실행한다. 실제 Firebase 토큰 발급·기기 알림 수신을 대신하지 않는다.

## 로컬 검증 기록 (2026-10-03)

- 기존 로컬 DB의 스키마만 별도 테스트 DB에 복사하여 migration과 SQL 테스트 통과.
- 실제 PostgREST + Deno handler + Flutter DataSource/Repository 통합 테스트 1개 통과: 등록, 교체, OFF, 재생성 후 선택 유지, 잘못된 비밀값, 오래된 ON, 직접 조회 차단.
- Edge handler 단위 테스트 10개, 앱/퀴즈 테스트 54개 통과. 환경변수 없는 일반 테스트에서는 실제 API 테스트 1개 skip.
- 적용 후 복구 SQL 실행 시 기존 스키마·정책·권한 보존 확인. Android 디버그 빌드, 변경 Dart 포맷, diff 검사 통과.
- flutter analyze는 기존 MyApp 참조 오류 등을 포함한 106건으로 실패했고 변경 알림 코드 진단은 없다.
- Firebase/APNs 연결, iOS 빌드와 실기기 수신, Supabase Edge 런타임 배포 검증은 실제 환경 준비 후 검증 대상.

## Phase 5 서버 발송

신규 `functions/send-notification/`은 FCM HTTP v1, 서버 OAuth, 작업별 발송·재시도·무효 토큰 정리를 처리한다. `20261003020000_notification_delivery.sql`의 push_jobs/push_deliveries는 중복 방지와 부분 실패를 기록하고 push_tokens 구조는 유지한다. 수동 호출·비활성 스케줄 설치와 계정 준비는 [NOTIFICATION_SETUP.md](NOTIFICATION_SETUP.md)에 정리했다.

Phase 5 검증: Deno 테스트 61개, 실제 격리 DB/PostgREST + handler 통합 1개, SQL 큐·권한·복구 테스트 통과. 스케줄 생성 SQL은 stub 확장에서 한국 시간/요일 변환·비활성 설치·인용 처리·제거를 검증했다. 실제 pg_cron/pg_net 실행과 원격 배포·실기기 발송은 미실행이다. 앱 회귀 54개 통과(환경변수 없는 API 1개 skip), analyze 기존 106건.

추가 검증 명령:

```sh
deno test --allow-read --allow-write supabase/functions/notification-installations/handler_test.ts supabase/functions/send-notification supabase/scripts
deno check supabase/functions/send-notification/index.ts supabase/scripts/*.ts
deno lint supabase/functions/send-notification supabase/scripts
deno fmt --check supabase/functions/send-notification supabase/scripts
```

`tests/notification_delivery_integration_test.ts`는 격리 PostgREST 직접 주소 NOTIFICATION_TEST_REST_URL과 서버 키 NOTIFICATION_TEST_SERVICE_KEY를 환경변수로 받아 실제 DB와 모의 FCM을 연결한다. 외부 FCM은 호출하지 않는다. `tests/notification_schedule_test.sql`은 quiz_notifications_로 시작하는 일회용 DB에서만 실행하며 실제 cron/net 스키마가 있으면 거부한다. 상대경로 구조를 유지해 psql -f로 실행한다.

## 대시보드 예약 확장 (Phase 2, 운영 미적용)

`migrations/20261004010000_notification_scheduling.sql`은 기존 두 알림 SQL 이후 적용한다. 기존 4개 테이블과 설치 API를 유지하고 예약 시각·시작 여부·출처·즉시/예약 구분만 추가한다. 발송 API의 예약 요청과 워커 처리 예산은 [NOTIFICATION_SETUP.md](NOTIFICATION_SETUP.md), 데이터 보존 복구는 [rollback/notification_scheduling.md](rollback/notification_scheduling.md)를 따른다.

격리 `quiz_notifications_` 접두사 DB에서 다음 순서로 검증한다. 기존 앱 DB를 초기화하지 않으며 실제 FCM을 호출하지 않는다.

1. 두 기존 알림 SQL → 신규 예약 SQL 적용.
2. `tests/notification_installations_test.sql`, `tests/notification_delivery_test.sql`, `tests/notification_scheduling_test.sql` 실행. 테스트 데이터는 rollback한다.
3. `tests/notification_schedule_test.sql`로 비활성 크론 설치와 워커 단독 재설치가 금·토 설정을 보존하는지 확인한다. 이 테스트는 실제 cron/net 대신 격리 스텁을 사용한다.
4. 앞의 Deno test/check/lint/fmt 명령으로 기존 전송과 예약/배치 처리 테스트를 실행한다.

실제 pg_cron/pg_net 실행, Firebase 수신, 네트워크 포함 운영 처리량은 별도 배포 검증 대상이다. 예약 대기 중에는 remaining=0일 수 있으므로 state=waiting을 완료로 해석하지 않는다.
