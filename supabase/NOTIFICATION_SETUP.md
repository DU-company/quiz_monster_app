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

| 이름 | 값 |
| --- | --- |
| FIREBASE_SERVICE_ACCOUNT | project_id/client_email/private_key를 가진 JSON |
| NOTIFICATION_SEND_KEY | 서버 발송 API 전용 32바이트 난수 hex, 앱에 넣지 않음 |

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
5. 성공 후 worker와 정기 enqueue 스케줄을 활성화한다. 롤백 시 먼저 스케줄을 제거하고 발송 migration을 되돌린 뒤 필요하면 설치 migration을 되돌린다.

## 수동 실행 API

POST `/functions/v1/send-notification` + `X-Notification-Key` 헤더로 호출한다. Supabase anon key나 앱 설치 비밀값은 발송 권한이 아니다. API는 웹 브라우저 직접 호출용이 아니며 관리자 웹 UI는 만들지 않았다. 향후 대시보드 서버에서도 같은 API를 호출할 수 있다.

요청 JSON 파일의 예시(설치 ID와 작업 ID는 실제 테스트 값으로 교체):

```json
{"action":"enqueue","job_id":"11111111-1111-4111-8111-111111111111","title":"퀴즈몬스터 테스트","body":"테스트 알림입니다.","installation_ids":["22222222-2222-4222-8222-222222222222"]}
```

`enqueue`는 등록만 한다. 전체 활성 설치 대상은 installation_ids 대신 `"all":true`를 명시한다. 같은 job_id+같은 내용 재요청은 중복 등록하지 않고, 같은 ID의 다른 내용은 409다. 새 발송은 새 UUID를 사용한다.

```json
{"action":"process","job_id":"11111111-1111-4111-8111-111111111111"}
```

`process`는 호출당 최대 5개 대상을 처리한다. job_id를 생략하면 전체 큐에서 선택하므로 테스트 중에는 항상 ID를 지정한다. 결과의 claimed는 실제 선택한 유효 대상 수이며 OFF/회전으로 건너뛴 행은 포함하지 않는다. claimed=0만으로 전체 완료를 판단하지 않는다.

```json
{"action":"status","job_id":"11111111-1111-4111-8111-111111111111"}
```

`status`의 remaining이 0이면 처리 종료다. 남아 있으면 next_attempt_at 이후 다시 process를 호출한다. 시간이 만료된 sending은 다음 process/current/finish에서 unknown으로 정리된다. 네트워크 오류가 나면 새 job_id를 만들지 말고 기존 ID 상태부터 확인한다.

NOTIFICATION_API_URL에 전체 함수 URL, NOTIFICATION_SEND_KEY에 서버 키를 설정한 터미널에서 다음처럼 호출한다. 키를 명령 인자나 요청 JSON에 넣지 않는다.

```sh
deno run --allow-env=NOTIFICATION_API_URL,NOTIFICATION_SEND_KEY --allow-read --allow-net supabase/scripts/notification-request.ts /요청.json
```

## 정기 발송

[Supabase 공식 방식](https://supabase.com/docs/guides/functions/schedule-functions)에 따라 pg_cron/pg_net과 Vault를 사용한다. 프로젝트에 두 확장을 활성화하고 Vault에 notification_project_url과 notification_send_key를 준비한다. 키 값은 Edge의 NOTIFICATION_SEND_KEY와 같아야 한다.

`install-notification-schedule.sql`은 hour_kst/minute/title/body를 psql 변수로 받으며 금·토 한국 시간을 UTC 요일/시간으로 변환한다. 시각은 매주 금·토 19:00 Asia/Seoul로 확정했다(hour_kst=19, minute=0, UTC cron `0 10 * * 5,6`). 제목·본문은 미정이므로 설치와 활성화는 아직 하지 않았다. 설치 직후 두 작업은 모두 **비활성**이다.

- quiz-monster-weekend-push: 지정한 한국 날짜별 고정 작업 ID로 전체 활성 대상 enqueue. 동일 날짜 재실행은 중복 등록하지 않는다.
- quiz-monster-push-worker: 매분 최대 5개 처리. 1분당 처리량은 작은 앱 기준이며 대규모 대상은 처리량 조정이 필요하다. 24시간 지난 미처리 작업은 건너뛴다.

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
