-- 일회성 예약용 워커만 설치/갱신한다. 금·토 등록 작업은 건드리지 않는다.
-- 설치 직후 비활성 상태이며 대상과 대기 작업을 확인한 후 활성화한다.
\set ON_ERROR_STOP on
begin;
do $worker_setup$
declare worker_id bigint;
begin
  if not exists (select 1 from vault.decrypted_secrets where name = 'notification_project_url') or
     not exists (select 1 from vault.decrypted_secrets where name = 'notification_send_key') then
    raise exception 'Configure notification_project_url and notification_send_key in Vault first';
  end if;
  select cron.schedule('quiz-monster-push-worker', '* * * * *', $worker$
    select net.http_post(
      url := (select decrypted_secret from vault.decrypted_secrets where name = 'notification_project_url') || '/functions/v1/send-notification',
      headers := jsonb_build_object('Content-Type','application/json','X-Notification-Key',(select decrypted_secret from vault.decrypted_secrets where name = 'notification_send_key')),
      body := '{"action":"process","max_batches":20}'::jsonb,
      timeout_milliseconds := 120000
    );
  $worker$) into worker_id;
  perform cron.alter_job(worker_id, active := false);
end;
$worker_setup$;
commit;
