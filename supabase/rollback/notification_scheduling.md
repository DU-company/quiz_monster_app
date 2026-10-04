# 알림 예약 변경 복구

자동 실행 스크립트가 아니라 운영자용 절차다. Phase 2에서는 운영 DB/크론을 변경하지 않는다.

1. 신규 대시보드 등록을 중단하고 공유 발송 워커를 비활성화한다. 금토 작업 등록도 중단하여 복구 중 큐가 늘지 않게 한다. 실행 중인 Edge 요청이 끝날 때까지 확인한다.
2. 적용 전/복구 전 `push_jobs`, `push_deliveries`, `push_tokens`, 함수 정의를 비공개 백업한다. 백업에는 메시지·토큰이 들어 있으므로 Git에 저장하지 않는다.
3. 기존 설치 register/sync 계약은 변경되지 않았다. 앱의 `acknowledged` 제거만 되돌릴 필요가 있으면 이전 앱 코드로 복구할 수 있다. secret/revision/payload는 그대로 유지된다.
4. 가장 안전한 서버 복구는 **추가한 열과 예약을 보존한 상태에서 워커를 중지하는 것**이다. Edge 구버전으로 복원해도 새 예약을 처리할 수 있다고 가정하지 않는다. DB의 `notification_schedule` 실행 권한을 회수하거나 신규 등록 경로를 닫는다.
5. 이전 DB 함수까지 복원해야 한다면 이전 delivery SQL에서 `notification_enqueue`, `notification_job_status`, `notification_claim`, `notification_delivery_current` 정의만 별도 검토 후 복원한다. CREATE TABLE을 포함한 이전 파일 전체를 재실행하지 않는다. `notification_finish`는 변경하지 않았다. 신규 열과 행을 삭제하지 않는다.
6. **이전 claim은 scheduled_at을 모르고 created_at 기준으로 처리한다.** 예약으로 생성한 delivery가 있거나 향후 예약이 남은 동안 이전 워커를 재개하지 않는다. 큐를 보존한 채 예약 지원 버전을 수정·재배포하는 것을 우선한다. 수동으로 예약 행/발송 상태를 바꿔 억지로 재개하지 않는다.
7. 재개 전 대기·sending·unknown 상태를 확인한다. sending의 전송 결과를 모르면 재발송하지 않는다. 이미 FCM에 전달된 메시지는 복구로 취소할 수 없다.
8. 격리 DB에서 예약 전/후, 대상 0건, UUID 재시도, 미래 예약 만료 방지와 기한 초과 제외를 확인한 뒤 새 워커를 재개한다. 운영 반영은 별도 승인된 배포 단계에서 수행한다.

## 추가 필드

- `scheduled_at`: 실제 처리 가능 시각. 기존 행은 created_at으로 채운다.
- `started_at`: 수신자 스냅샷 완료 시각. 기존 행은 이미 확정된 것으로 간주한다.
- `source`: legacy 또는 dashboard.
- `is_scheduled`: 명시 예약과 즉시 요청을 구분한다. 즉시 재시도에서 매번 새 시각을 생성해 충돌하지 않게 하는 최소 표식이다.

미래 예약의 started_at이 NULL이고 remaining=0인 것은 완료가 아니다. 상태 state=waiting을 사용한다. 시작 전 24시간 기한 초과만 expired이고, 시작 후 건별 제외 결과는 counts.skipped와 complete/processing으로 표시한다.
