begin;
-- 발송 작업 이력도 삭제되므로 운영 적용 전 별도로 보관한다.
drop function public.notification_finish(uuid,uuid,uuid,text,integer);
drop function public.notification_delivery_current(uuid,uuid,uuid);
drop function public.notification_claim(uuid,integer);
drop function public.notification_enqueue(uuid,text,text,uuid[]);
drop function public.notification_job_status(uuid);
drop table public.push_deliveries;
drop table public.push_jobs;
commit;
