-- 운영 대상·문구·시간 확인 후에만 실행하며 설치 직후 두 작업 모두 비활성 상태다.
\set ON_ERROR_STOP on
\if :{?hour_kst}
\else
  \echo 'hour_kst, minute, title, body 변수가 필요합니다.'
  do $$ begin raise exception 'Missing schedule variables'; end $$;
\endif
begin;
create temporary table notification_schedule_input (hour_kst int, minute int, title text, body text) on commit drop;
insert into notification_schedule_input values (:'hour_kst'::int, :'minute'::int, :'title', :'body');
do $schedule$
declare settings record; utc_hour int; utc_days text; command text; worker_id bigint; weekend_id bigint;
begin
  select * into settings from notification_schedule_input;
  if settings.hour_kst not between 0 and 23 or settings.minute not between 0 and 59 or btrim(settings.title) = '' or length(settings.title) > 120 or octet_length(settings.title) > 480 or btrim(settings.body) = '' or length(settings.body) > 1000 or octet_length(settings.body) > 3000 then
    raise exception 'Invalid schedule settings';
  end if;
  if current_setting('cron.timezone', true) is not null and current_setting('cron.timezone', true) not in ('GMT','UTC') then
    raise exception 'This installer requires pg_cron UTC timezone';
  end if;
  if not exists (select 1 from vault.decrypted_secrets where name = 'notification_project_url') or not exists (select 1 from vault.decrypted_secrets where name = 'notification_send_key') then
    raise exception 'Configure notification_project_url and notification_send_key in Vault first';
  end if;
  utc_hour := (settings.hour_kst + 15) % 24;
  utc_days := case when settings.hour_kst < 9 then '4,5' else '5,6' end;
  -- 같은 한국 날짜의 재실행은 같은 작업 ID를 사용해 중복 등록을 막는다.
  command := format('select public.notification_enqueue(md5(''quiz-monster:weekend:'' || (now() at time zone ''Asia/Seoul'')::date::text)::uuid, %L, %L, null);', settings.title, settings.body);
  select cron.schedule('quiz-monster-weekend-push', format('%s %s * * %s',settings.minute,utc_hour,utc_days), command) into weekend_id;
  select cron.schedule('quiz-monster-push-worker','* * * * *', $worker$
    select net.http_post(
      url := (select decrypted_secret from vault.decrypted_secrets where name = 'notification_project_url') || '/functions/v1/send-notification',
      headers := jsonb_build_object('Content-Type','application/json','X-Notification-Key',(select decrypted_secret from vault.decrypted_secrets where name = 'notification_send_key')),
      body := '{"action":"process","max_batches":20}'::jsonb,
      timeout_milliseconds := 120000
    );
  $worker$) into worker_id;
  perform cron.alter_job(weekend_id, active := false);
  perform cron.alter_job(worker_id, active := false);
end;
$schedule$;
commit;
