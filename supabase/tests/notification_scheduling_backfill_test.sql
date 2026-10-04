-- Requires a fresh disposable DB. This test deliberately applies migrations in order.
\set ON_ERROR_STOP on
do $$ begin
  if current_database() not like 'quiz\_notifications\_%' escape '\' or to_regclass('public.push_jobs') is not null then
    raise exception 'Requires a fresh disposable quiz_notifications_ database';
  end if;
end; $$;
\ir ../migrations/20261003010000_notification_installations.sql
\ir ../migrations/20261003020000_notification_delivery.sql
insert into public.push_tokens(installation_id,credential_hash,fcm_token,enabled)
 values('10000000-0000-4000-8000-000000000001',repeat('a',64),'backfill-token',true);
select public.notification_enqueue('20000000-0000-4000-8000-000000000001','existing','body');
select public.notification_enqueue('20000000-0000-4000-8000-000000000002','existing empty','body',array['10000000-0000-4000-8000-000000000002'::uuid]);
\ir ../migrations/20261004010000_notification_scheduling.sql
do $$ declare n integer; begin
  assert (select bool_and(scheduled_at=created_at and started_at=created_at and source='legacy' and not is_scheduled) from public.push_jobs);
  insert into public.push_tokens(installation_id,credential_hash,fcm_token,enabled)
    values('10000000-0000-4000-8000-000000000002',repeat('b',64),'backfill-new-token',true);
  select count(*) into n from public.notification_claim('20000000-0000-4000-8000-000000000001',5);
  assert n=1, 'old recipient snapshot changed';
  select count(*) into n from public.notification_claim('20000000-0000-4000-8000-000000000002',5);
  assert n=0, 'old empty recipient snapshot repopulated';
  assert (public.notification_job_status('20000000-0000-4000-8000-000000000002')->>'state')='complete';
end; $$;
