-- 실제 pg_cron/pg_net 실행 대신 생성된 SQL과 설정만 검증하는 격리 DB 전용 테스트다.
\set ON_ERROR_STOP on

do $$
begin
  if current_database() not like 'quiz\_notifications\_%' escape '\' then
    raise exception 'Run only in a disposable quiz_notifications_ database';
  end if;
  if to_regnamespace('cron') is not null or to_regnamespace('net') is not null then
    raise exception 'This test requires absent cron and net schemas; never replace real extensions';
  end if;
  if exists(select 1 from vault.decrypted_secrets where name in ('notification_project_url','notification_send_key')) then
    raise exception 'This test requires absent notification Vault secrets; never replace configured secrets';
  end if;
end;
$$;

create temporary table notification_schedule_test_secrets(id uuid);
insert into notification_schedule_test_secrets select vault.create_secret('http://127.0.0.1:54321','notification_project_url');
insert into notification_schedule_test_secrets select vault.create_secret(repeat('a',64),'notification_send_key');
create temporary table notification_schedule_expected(title text,body text);
insert into notification_schedule_expected values ($text$금요일 '알림'; -- 제목$text$, $text$본문 '인용'; select '아무것도 실행하지 않음';
다음 줄 \ 경로$text$);

create schema cron;
create table cron.job(jobid bigint generated always as identity primary key,jobname text unique,schedule text,command text,active boolean not null default true);
create function cron.schedule(job_name text,schedule text,command text) returns bigint language sql as $$
  insert into cron.job(jobname,schedule,command) values($1,$2,$3)
  on conflict(jobname) do update set schedule=excluded.schedule,command=excluded.command
  returning jobid;
$$;
create function cron.alter_job(job_id bigint,active boolean) returns void language sql as $$
  update cron.job set active=$2 where jobid=$1;
$$;
create function cron.unschedule(job_id bigint) returns boolean language plpgsql as $$
begin
  delete from cron.job where jobid=job_id;
  return found;
end;
$$;
create schema net;
create table net.test_requests(url text,headers jsonb,body jsonb,timeout_milliseconds integer);
create function net.http_post(url text,headers jsonb,body jsonb,timeout_milliseconds integer) returns bigint language plpgsql as $$
begin
  insert into net.test_requests values($1,$2,$3,$4);
  return 1;
end;
$$;

select 21 as hour_kst, 17 as minute, title, body from notification_schedule_expected \gset
\ir ../scripts/install-notification-schedule.sql

do $$
declare command_ text;
begin
  assert (select count(*)=2 and bool_and(not active) from cron.job), 'installed schedules must be disabled';
  assert (select schedule='17 12 * * 5,6' from cron.job where jobname='quiz-monster-weekend-push'), 'KST evening UTC schedule incorrect';
  assert (select schedule='* * * * *' from cron.job where jobname='quiz-monster-push-worker');
  select command into command_ from cron.job where jobname='quiz-monster-push-worker';
  execute command_;
  assert (select count(*)=1 from net.test_requests);
  assert (select url='http://127.0.0.1:54321/functions/v1/send-notification'
    and headers=jsonb_build_object('Content-Type','application/json','X-Notification-Key',repeat('a',64))
    and body='{"action":"process"}'::jsonb and timeout_milliseconds=120000 from net.test_requests);
end;
$$;

-- 생성된 등록 SQL을 실제 파싱·실행하되 발송 작업과 수신자 기록은 롤백한다.
begin;
do $$
declare command_ text; id_ uuid := md5('quiz-monster:weekend:' || (now() at time zone 'Asia/Seoul')::date::text)::uuid;
begin
  if exists(select 1 from public.push_jobs where id=id_) then
    raise exception 'Disposable database already has today''s weekend job';
  end if;
  select command into command_ from cron.job where jobname='quiz-monster-weekend-push';
  execute command_;
  execute command_;
  assert (select count(*)=1 from public.push_jobs where id=id_), 'same-day repeat is not idempotent';
  assert (select j.title=e.title and j.body=e.body and j.target_ids is null
    from public.push_jobs j cross join notification_schedule_expected e where j.id=id_), 'SQL literal quoting changed content';
end;
$$;
rollback;

select 8 as hour_kst, 3 as minute, title, body from notification_schedule_expected \gset
\ir ../scripts/install-notification-schedule.sql

do $$
begin
  assert (select count(*)=2 and bool_and(not active) from cron.job), 'reinstall duplicated or enabled schedules';
  assert (select schedule='3 23 * * 4,5' from cron.job where jobname='quiz-monster-weekend-push'), 'KST morning must use prior UTC weekdays';
end;
$$;
select cron.schedule('unrelated-test-job','0 0 * * *','select 1;');
\ir ../scripts/remove-notification-schedule.sql

do $$
begin
  assert (select count(*)=1 and min(jobname)='unrelated-test-job' from cron.job), 'removal affected unrelated schedule or missed push jobs';
end;
$$;

-- 성공한 테스트가 만든 스텁과 더미 자격 정보만 정리한다.
drop function net.http_post(text,jsonb,jsonb,integer);
drop table net.test_requests;
drop schema net;
drop function cron.schedule(text,text,text);
drop function cron.alter_job(bigint,boolean);
drop function cron.unschedule(bigint);
drop table cron.job;
drop schema cron;
delete from vault.secrets where id in(select id from notification_schedule_test_secrets);
drop table notification_schedule_test_secrets;
drop table notification_schedule_expected;
