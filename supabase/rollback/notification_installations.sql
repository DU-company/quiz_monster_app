begin;

-- 알림 저장 데이터도 제거하므로 적용 대상과 백업을 먼저 확인한다.
drop function public.notification_register(uuid,text);
drop function public.notification_sync(uuid,text,bigint,boolean,text);
drop function public.notification_invalidate_token(uuid,text);
drop function public.notification_active_tokens();
drop function public.notification_take_rate_limit(text,integer,integer);
drop table public.push_tokens;
drop table public.push_token_rate_limits;
drop function public.notification_token_hash(text);

commit;
