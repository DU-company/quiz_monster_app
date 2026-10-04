# 푸시 준비와 운영

## 사용자가 준비할 것

현재 Firebase 앱 등록과 설정 파일·서비스 계정 JSON 배치를 확인했다. APNs 연결과 실기기 수신은 미검증이다. 아래 1~3번 파일 준비는 완료했고, 4번 APNs 연결을 진행한다.

1. Firebase Console에서 사용할 프로젝트를 만든다. Android 앱 패키지는 `com.du.quiz_monster`, iOS 번들 ID는 `com.du.quizmonster`로 등록한다.
2. Android `google-services.json`과 iOS `GoogleService-Info.plist`를 다운로드한다. 파일 경로를 알려주면 코드의 초기화·빌드 설정 연결은 에이전트가 진행한다. 두 파일 배치와 프로젝트/앱 ID 일치를 확인했다.
3. Firebase 프로젝트 설정 → 서비스 계정에서 서버용 비공개 키 JSON을 발급해 저장소 밖의 안전한 위치에 저장한다. 서버 계정에 FCM 발송 권한과 Firebase Cloud Messaging API가 필요하다. 키 내용은 채팅이나 Git에 넣지 않고 경로만 전달한다.
4. iOS는 Apple Developer에서 해당 App ID의 Push Notifications를 준비하고 APNs 인증 키(.p8), Key ID, Team ID를 Firebase의 Cloud Messaging/iOS 설정에 연결한다. Apple 계정·서명 권한과 실제 iPhone이 필요하다. Xcode 프로젝트의 capability/entitlements 연결은 파일과 계정 준비 후 에이전트가 처리한다.
5. 원격 Supabase 대상 프로젝트, 테스트 기기 사용 가능 여부, 금·토요일 한국 시간의 발송 시각과 제목/본문을 확정한다. 먼저 한 테스트 설치로 검증한 후 자동 발송을 켠다.

Firebase 공식 문서: [Flutter 설정](https://firebase.google.com/docs/cloud-messaging/flutter/get-started), [서버 인증](https://firebase.google.com/docs/cloud-messaging/send/v1-api).

## 에이전트가 처리할 것

- 다운로드한 앱 설정 파일과 Android/iOS 초기화 연결, 필요한 capability 구성과 빌드 검증.
- 서버 인증 파일에서 필요한 설정만 추출해 Supabase secrets 등록, 대상 DB migration/Edge Function 배포.
- 테스트 기기 설치 ID만 지정해 등록→발송→OFF→토큰 교체 검증. 사용자는 기기에서 권한을 허용하고 수신 여부를 확인한다.
- 확정된 문구·시간으로 스케줄 설치와 활성화. 코드 검증과 실제 배포/수신 검증을 구분해서 기록한다.

## 서버 설정

Edge Function은 자동 주입되는 SUPABASE_URL/SUPABASE_SERVICE_ROLE_KEY와 다음 두 secret을 사용한다.

| 이름                     | 값                                                   |
| ------------------------ | ---------------------------------------------------- |
| FIREBASE_SERVICE_ACCOUNT | project_id/client_email/private_key를 가진 JSON      |
| NOTIFICATION_SEND_KEY    | 서버 발송 API 전용 32바이트 난수 hex, 앱에 넣지 않음 |

비공개 JSON 경로를 받은 뒤 다음 도구로 출력 파일을 만든다. 기존 파일을 덮어쓰지 않고 0600 권한으로 생성하며 값을 출력하지 않는다. 출력 경로는 저장소 밖이나 무시되는 `.env.*`여야 한다.

```sh
deno run --allow-read --allow-write supabase/scripts/prepare-notification-secrets.ts /안전한/서비스계정.json /안전한/notification.env
supabase secrets set --project-ref PROJECT_REF --env-file /안전한/notification.env
```

이 명령은 실제 Supabase에 설정을 쓰므로 대상이 확정된 뒤 실행한다. 발송 키를 다시 생성하면 호출 도구와 Vault도 같이 변경한다.

## 적용 순서

1. 기존 migration 이력을 확인하고 격리 로컬 DB에 먼저 20261003010000, 20261003020000 순서로 적용한다. 기존 DB를 reset하지 않는다.
2. 확인된 원격 DB에 동일 migration을 적용한다. 이 앱의 supabase 폴더에는 전체 퀴즈 baseline이 없으므로 대상 이력 확인 없이 `db push`를 실행하지 않는다.
3. 서버 secrets를 등록하고 `notification-installations`, `send-notification`을 배포한다. 두 함수는 각각 설치 비밀값/발송 전용 키로 인증하고 verify_jwt=false다.
4. 확인된 테스트 설치에만 수동 발송한다. 앱 사용자가 OS 권한을 허용해야 활성 토큰이 등록된다.
5. 대기 큐와 영향을 확인한 후 worker를 활성화한다. 금·토 enqueue는 문구 확정 후 별도로 활성화한다. 복구는 우선 신규 등록·worker를 중지하고 큐를 보존하며, `rollback/notification_scheduling.md`를 따른다. 예약 데이터가 남아 있는 상태에서 구버전 claim을 재개하지 않는다.

## 수동 실행 API

POST `/functions/v1/send-notification` + `X-Notification-Key` 헤더로 호출한다. Supabase anon key나 앱 설치 비밀값은 발송 권한이 아니다. API는 웹 브라우저 직접 호출용이 아니다. 관리자 웹의 서버 전용 API가 같은 키로 호출하며 `/notifications`에서 즉시·일회성 예약을 등록한다.

요청 JSON 파일의 예시(설치 ID와 작업 ID는 실제 테스트 값으로 교체):

```json
{
  "action": "enqueue",
  "job_id": "11111111-1111-4111-8111-111111111111",
  "title": "퀴즈몬스터 테스트",
  "body": "테스트 알림입니다.",
  "installation_ids": ["22222222-2222-4222-8222-222222222222"]
}
```

`enqueue`는 등록만 한다. 전체 활성 설치 대상은 installation_ids 대신 `"all":true`를 명시한다. 같은 job_id+같은 내용 재요청은 중복 등록하지 않고, 같은 ID의 다른 내용은 409다. 새 발송은 새 UUID를 사용한다.

```json
{ "action": "process", "job_id": "11111111-1111-4111-8111-111111111111" }
```

`process`는 기본 호출당 최대 5개 대상을 처리한다. `max_batches`를 1~20으로 지정하면 배치당 최대 5개를 순차 처리하며 한 호출의 상한은 100개다. 30초가 지나면 새 배치를 시작하지 않고 진행 중인 결과 저장을 마친다. 결과 저장 오류가 있으면 추가 배치를 중단한다. job_id를 생략하면 전체 큐에서 선택하므로 테스트 중에는 항상 ID를 지정한다. 결과의 claimed는 실제 선택한 유효 대상 수이며 OFF/회전으로 건너뛴 행은 포함하지 않는다. claimed=0만으로 전체 완료를 판단하지 않는다.

```json
{ "action": "status", "job_id": "11111111-1111-4111-8111-111111111111" }
```

`status`의 state가 waiting이면 아직 대상을 만들지 않은 예약/즉시 작업이다. 이때 remaining=0이어도 완료가 아니다. processing은 처리 중, complete는 처리 종료이며 실패/건너뜀을 포함할 수 있다. expired는 시작 전에 처리 기한을 넘긴 작업이다. next_attempt_at은 다음 조회·처리 판단에 사용한다. 시간이 만료된 sending은 다음 process/current/finish에서 unknown으로 정리된다. 네트워크 오류가 나면 새 job_id를 만들지 말고 기존 ID 상태부터 확인한다.

NOTIFICATION_API_URL에 전체 함수 URL, NOTIFICATION_SEND_KEY에 서버 키를 설정한 터미널에서 다음처럼 호출한다. 키를 명령 인자나 요청 JSON에 넣지 않는다.

```sh
deno run --allow-env=NOTIFICATION_API_URL,NOTIFICATION_SEND_KEY --allow-read --allow-net supabase/scripts/notification-request.ts /요청.json
```

## 정기 발송

[Supabase 공식 방식](https://supabase.com/docs/guides/functions/schedule-functions)에 따라 pg_cron/pg_net과 Vault를 사용한다. 프로젝트에 두 확장을 활성화하고 Vault에 notification_project_url과 notification_send_key를 준비한다. 키 값은 Edge의 NOTIFICATION_SEND_KEY와 같아야 한다.

`install-notification-schedule.sql`은 hour_kst/minute/title/body를 psql 변수로 받으며 금·토 한국 시간을 UTC 요일/시간으로 변환한다. 시각은 매주 금·토 19:00 Asia/Seoul로 확정했다(hour_kst=19, minute=0, UTC cron `0 10 * * 5,6`). 제목·본문은 미정이므로 설치와 활성화는 아직 하지 않았다. 설치 직후 두 작업은 모두 **비활성**이다.

- quiz-monster-weekend-push: 지정한 한국 날짜별 고정 작업 ID로 전체 활성 대상 enqueue. 동일 날짜 재실행은 중복 등록하지 않는다.
- quiz-monster-push-worker: 매분 최대 20배치 × 5개를 처리한다. 실제 처리량은 30초 배치 시작 예산과 네트워크 지연에 따라 더 적을 수 있다. 예정 시각부터 24시간을 넘긴 미처리 작업은 건너뛴다. 서로 다른 작업의 대상을 번갈아 선택하여 큰 작업이 다른 발송을 계속 밀어내지 않게 한다.

활성화는 Supabase Cron 화면에서 두 작업을 켜거나 `cron.alter_job(..., active := true)`를 사용한다. 수정 설치도 다시 비활성화되므로 설정을 확인하고 켠다. 제거는 `scripts/remove-notification-schedule.sql`로 두 이름의 작업만 삭제한다. worker를 끄면 재시도도 멈춘다.

## 결과와 한계

push_tokens는 6개 필드를 유지한다. 추가 push_jobs/push_deliveries는 작업 중복 방지와 대상별 처리 결과에만 사용하며 토큰 원문은 복제하지 않고 해시를 저장한다. 기록을 자동 삭제하면 같은 ID의 재발송을 막을 수 없으므로 현재 자동 정리하지 않는다. 운영량에 맞는 별도 보존 정책이 필요하다.

- sent: FCM 서버가 수락했다는 뜻이며 기기 수신 보장은 아니다.
- invalid: FCM의 명확한 UNREGISTERED 오류. 실패한 토큰이 여전히 현재 값인 경우만 비활성화한다.
- retry: 429/500/503 등 명확한 일시 실패. Retry-After와 최소 60초부터의 지수 지연을 지키며 전체 최대 3회 시도한다.
- failed: 영구 오류 또는 재시도 소진. 인증/설정 오류도 포함되므로 원인을 수정한 뒤 실패 대상만 새 작업으로 보낸다.
- unknown: 네트워크 응답 유실, 발송 중 종료 등 성공 여부가 불확실하다. 중복 발송 방지를 우선하여 자동 재시도하지 않으므로 일부 누락 가능성이 있다.
- skipped: OFF, 토큰 교체 또는 24시간 대기 만료. 새 토큰으로 자동 대상을 바꾸지 않는다.

DB 확인과 외부 FCM 요청은 하나의 트랜잭션이 아니므로 확인 직후 OFF가 발생하는 아주 짧은 구간까지 차단할 수 없다. 오프라인 OFF는 서버 동기화 전까지 알 수 없다. 원격 배포, 실제 pg_cron/pg_net 실행과 실기기 수신은 별도 검증해야 한다.

## 적용 상태 (2026-10-04)

Quiz_Monster 원격 DB에 두 알림 migration과 이력을 적용하고 함수 두 개를 배포했다. iOS 개발 서명 빌드와 APNs entitlement 검증을 통과했다. 서버 secrets 업로드는 자동 승인 검토에서 사용자 명시적 승인이 필요해 차단됐다. 실제 기기 푸시·자동 스케줄은 아직 실행하지 않았다.

사용자의 명시적 승인 후 2026-10-04 서버 secrets 등록을 완료했다. 인증된 API의 대상 없는 요청이 HTTP 200으로 정상 응답했다. 실제 기기 발송과 정기 스케줄 활성화는 아직 미실행이다.

## 대시보드 일회성 예약

기존 enqueue 계약과 금·토 등록 SQL은 그대로 유지한다. 새로운 대시보드 요청에는 `source: "dashboard"`를 보낸다. `scheduled_at`을 생략하거나 null로 보내면 즉시 작업이며, 시간대를 포함한 ISO 시각을 보내면 일회성 예약이다. 제목·본문 제한은 기존과 같다.

```json
{
  "action": "schedule",
  "source": "dashboard",
  "job_id": "11111111-1111-4111-8111-111111111111",
  "title": "공휴일 퀴즈",
  "body": "오늘도 함께 즐겨요!",
  "scheduled_at": "2030-01-01T19:00:00+09:00",
  "all": true
}
```

예시는 전체 대상 요청이므로 검증에서는 all 대신 테스트 설치 UUID 배열을 사용한다. 신규 예약은 DB의 현재 시각보다 미래여야 한다. 같은 UUID·내용·대상·시각으로 재요청하면 예정 시각이 지난 후에도 원래 작업을 반환한다. 즉시 요청은 최초 저장 시각을 재사용한다. 즉시↔예약 변경 또는 내용 변경에는 같은 UUID를 사용할 수 없다.

예약 도래 시 서버가 수신 대상을 한 번만 확정한다. 예약 이후 동의한 설치도 시작 시 활성 상태이면 포함되며, 시작 전에 거부한 설치는 제외된다. 시작 후 토큰이 바뀌거나 OFF가 되면 해당 발송은 건너뛴다. 수신자 0건도 시작 완료로 남겨 나중에 새 기기를 추가해 보내지 않는다.

`scheduled_at`은 유효 발송 시각, `is_scheduled`는 사용자 지정 예약 여부, `started_at`은 수신자 확정 여부, `source`는 기존 호출/대시보드 구분이다. 예약을 며칠 전에 등록해도 생성 시각 때문에 만료되지 않으며 유효 발송 시각부터 24시간이 처리 기한이다. 응답의 counts는 기존 기기별 결과를 유지하고 제목·본문·시각·state를 추가한다.

금·토 제목/시간과 무관하게 워커만 설치하려면 `scripts/install-notification-worker.sql`을 사용한다. 기존 금·토 작업은 변경하지 않고 워커만 비활성 상태로 설치한다. pg_cron·pg_net과 Vault 설정 및 대상 DB 확인 후 실행하며, 큐와 영향을 확인하고 활성화해야 예약이 실제 진행된다. 브라우저는 워커 실행에 관여하지 않는다.

배포는 `20261004010000_notification_scheduling.sql` → 새 send-notification 함수 → 워커 설정 순서다. 운영 DB에 적용하기 전 알림 테이블 정의/행을 비공개 경로에 백업한다. 기존 데이터의 started_at은 created_at으로 채워 이미 생성된 수신자를 다시 만들지 않는다. 이 단계에서 운영 DB와 크론을 자동 변경하지 않는다.

복구 시 신규 등록과 워커를 먼저 중지하고 큐를 보존한다. 새 예약이 남은 상태에서 예전 claim으로 워커를 재개하면 예약 시각을 무시할 수 있으므로 허용하지 않는다. 상세 복구 절차는 `rollback/notification_scheduling.md`를 따른다. 이미 FCM에 전달한 알림은 취소할 수 없다.

## 웹 관리자 API용 목록과 전용 등록 액션

웹 서버는 `action: "schedule"`로 등록한다. 내용·대상·scheduled_at 계약은 위
enqueue 확장과 같지만, 예약 필드를 모르는 구버전 Edge가 즉시 발송으로 오해하지
않도록 새 액션을 사용한다. 즉시 발송도 이 액션에 null 시각을 보낸다. 기존
enqueue 호출은 호환성을 유지한다.

`action: "list"`, 선택적 `page`(1~10,000), `page_size`(1~100, 기본50)는
dashboard 작업만 `{jobs,total,page,page_size}`로 반환한다. 목록과 status는
Firebase 설정 없이 조회 가능하지만 발송 API 키 인증은 항상 필요하다. 조회는 작업
시작/대상 생성/발송을 실행하지 않는다.

예약 SQL 이후 `migrations/20261004020000_notification_listing.sql`을 적용하고 새
Edge를 배포한 다음 웹을 연결한다. 목록 RPC도 service_role만 실행 가능하며 웹에는
service-role 키를 배포하지 않는다. 이 액션들은 현재 관리자 웹 서버에서 사용하며
기존 수동 CLI의 지원 액션은 enqueue/process/status다.

## Phase 5 운영 연결 — 2026-10-04

- 대상: `ecgixrbdqlkshkpnelsa`. 예약·목록 SQL 두 개를 각 트랜잭션과 migration
  이력으로 적용하고 `send-notification` 새 버전을 배포했다. 설치 등록 함수는
  변경하지 않았다.
- 기존 로컬 발송 키와 운영 secret의 SHA-256이 일치하는지 확인한 후 웹
  `.env.local`의 서버 전용 `NOTIFICATION_SEND_KEY`에 연결했다. 키를 재발급하지
  않았고 Firebase 계정·service-role 키를 웹에 넣지 않았다. Vercel은 아직
  배포하지 않았으므로 배포 시 같은 서버 전용 키가 별도로 필요하다.
- `pg_cron`·`pg_net` 활성화, Vault의
  `notification_project_url`·`notification_send_key` 연결,
  `install-notification-worker.sql` 설치를 완료했다. 사용자가 운영 워커 활성화를
  명시적으로 승인한 후 대기 작업 없음까지 재확인하여 매분 worker를 켰다. 금·토
  등록 작업은 설치·활성화하지 않았다. 해당 시각·문구의 기존 결정은 유지한다.
- 사전 백업: Git 제외 `.supabase-local/notification-phase5-20261004/`의
  `before.json`(행·컬럼·제약·인덱스·RLS/권한·함수·이력), 이전 SQL 두 개,
  `edge-before/`의 운영 함수 원본. 디렉터리는 0700, 민감 파일은 0600이며 키·토큰
  원문은 출력하지 않았다. 이 경로의 파일은 Git에 추가하지 않는다.
- 인증된 Edge 목록 조회 HTTP 200과 존재하지 않는 작업 ID를 지정한 process의
  `claimed=0` 응답을 확인했다. cron의 실행 성공만으로 FCM 성공을 판단하지 않고
  pg_net HTTP 결과도 확인한다.
- 실제 기기 테스트는 확인된 설치 UUID로만 진행한다. 수신자 없는 서버 검증과 FCM
  접수·실기기 수신은 별도로 보고한다. 새 전체 대상 테스트 발송은 하지 않는다.

### 점검·중지

```sql
select jobname, schedule, active from cron.job
where jobname = 'quiz-monster-push-worker';
select status, start_time, end_time from cron.job_run_details
where jobid = (select jobid from cron.job where jobname = 'quiz-monster-push-worker')
order by runid desc limit 5;
select status_code, timed_out, error_msg, created from net._http_response
order by id desc limit 5;
-- 중지할 때만 실행한다. 큐·키·예약은 보존한다.
select cron.alter_job(jobid, active := false) from cron.job
where jobname = 'quiz-monster-push-worker';
```

새 예약 접수도 막으려면 웹 서버의 발송 키를 제거하고 재시작/재배포한다. 다른
직접 Edge 등록 경로가 있다면 해당 운영 경로도 중지한다. 재개 전
pending/retry/sending 및 미시작 예약을 확인한다. 이미 FCM에 전달된 메시지는
취소할 수 없다.

### 회귀 검증

Deno 함수·도구 테스트 77개, SQL 6종, 두 worker 동시 처리, 격리 PostgREST+모의
FCM 통합 2개를 통과했다. 신규 `notification_scheduling_integration_test.ts`는
기존 정기+예약 동시 도래, OFF/토큰 교체, 부분 재시도와 24시간 초과 중단을
검증한다. `NOTIFICATION_TEST_REST_URL`은 loopback만 허용하고
`NOTIFICATION_TEST_DB_NAME`은 폐기 가능한 `quiz_notifications_*` DB여야 한다.
Docker DB/권한/PostgREST 준비 후 다음처럼 실행하며 운영 DB나 실제 FCM은 사용하지
않는다.

```sh
deno test --allow-env --allow-net=127.0.0.1 --allow-run=docker supabase/tests/notification_scheduling_integration_test.ts
```

앱 알림 테스트 29개 통과, 로컬 API 설정을 요구하는 1개는 건너뛰었다. 관련 파일
format/analyze는 통과했으며 전체 analyzer의 기존 106개 진단(오래된 widget_test의
MyApp 참조 포함), 미변경 설치 handler_test의 require-await lint 5건은 별도 기존
문제로 남겨 두었다.

수신자 없는 운영 검증 2건: 즉시 15:28:26→15:29:02 KST, 예약 15:30:31→15:31:00 KST에 서버 cron으로 완료됐다. 예정 전 waiting도 확인했고 실제 수신자·FCM 전송은 0건이다. 작업 내역은 보존했다. 실기기 즉시·예약 수신은 테스트 기기 확인 및 발송 승인 대기다.

## iOS 잠금 화면 알림음 수정 — 2026-10-04

FCM 발송 payload에 iOS 기본 알림음이 빠져 있어 `apns.payload.aps.sound="default"`를 추가했다. APNs alert와 일반 `active` interruption level, push-type=alert/priority=10을 명시했다. Android 설정과 앱 전경 SnackBar 동작은 유지한다. 무음·집중 모드를 무시하는 critical/time-sensitive 알림은 사용하지 않는다. 앱 재설치 없이 새 서버 발송부터 적용된다.

send-notification 테스트 60개, 타입·lint·포맷 검사를 통과한 뒤 운영 함수에 배포했다. 이전 함수는 Git 제외 `.supabase-local/notification-ios-sound-20261004/`에 보관했다. 실제 기기 소리·진동·화면 켜짐은 사용자 재검증이 필요하며 이번 수정 검증에서 실제 테스트 알림을 보내지는 않았다. iOS 설정의 앱 소리·잠금 화면 표시, 무음·집중 모드 및 햅틱 설정도 영향을 준다.

참고: [Apple 원격 알림 payload](https://developer.apple.com/documentation/usernotifications/generating-a-remote-notification), [iPhone 알림 설정](https://support.apple.com/en-gb/guide/iphone/iph7c3d96bab/ios).
