begin;

create table public.push_jobs (
  id uuid primary key,
  title text not null check (length(title) between 1 and 120 and octet_length(title) <= 480 and btrim(title) <> ''),
  body text not null check (length(body) between 1 and 1000 and octet_length(body) <= 3000 and btrim(body) <> ''),
  target_ids uuid[] check (target_ids is null or (cardinality(target_ids) between 1 and 100 and array_position(target_ids, null) is null)),
  created_at timestamptz not null default clock_timestamp()
);
create table public.push_deliveries (
  job_id uuid not null references public.push_jobs(id),
  installation_id uuid not null,
  token_hash bytea not null,
  status text not null default 'pending' check (status in ('pending','retry','sending','sent','invalid','failed','skipped','unknown')),
  attempts integer not null default 0 check (attempts between 0 and 3),
  available_at timestamptz not null default clock_timestamp(),
  claim_id uuid,
  updated_at timestamptz not null default clock_timestamp(),
  primary key (job_id, installation_id)
);
create index push_deliveries_ready on public.push_deliveries (available_at, job_id) where status in ('pending','retry');
create index push_deliveries_sending on public.push_deliveries (updated_at) where status = 'sending';
alter table public.push_jobs enable row level security;
alter table public.push_deliveries enable row level security;
revoke all on public.push_jobs, public.push_deliveries from public, anon, authenticated, service_role;

create function public.notification_job_status(p_job_id uuid)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare counts_ jsonb; remaining_ integer; next_ timestamptz;
begin
  if not exists (select 1 from public.push_jobs where id = p_job_id) then
    raise exception using errcode = 'PT404', message = 'job_not_found';
  end if;
  select jsonb_object_agg(s.status, coalesce(c.total, 0)) into counts_
    from unnest(array['pending','retry','sending','sent','invalid','failed','skipped','unknown']) as s(status)
    left join (select status, count(*) total from public.push_deliveries where job_id = p_job_id group by status) c using (status);
  select count(*), min(case when status = 'sending' then updated_at + interval '5 minutes' else available_at end)
    into remaining_, next_ from public.push_deliveries where job_id = p_job_id and status in ('pending','retry','sending');
  return jsonb_build_object('job_id', p_job_id, 'counts', counts_, 'remaining', remaining_, 'next_attempt_at', next_);
end;
$$;

create function public.notification_enqueue(p_job_id uuid, p_title text, p_body text, p_target_ids uuid[] default null)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare targets_ uuid[]; item public.push_jobs; inserted_ boolean;
begin
  if p_job_id is null or p_title is null or length(p_title) not between 1 and 120 or octet_length(p_title) > 480 or btrim(p_title) = ''
    or p_body is null or length(p_body) not between 1 and 1000 or octet_length(p_body) > 3000 or btrim(p_body) = ''
    or (p_target_ids is not null and (cardinality(p_target_ids) not between 1 and 100 or array_position(p_target_ids, null) is not null)) then
    raise exception using errcode = 'PT400', message = 'invalid_request';
  end if;
  if p_target_ids is not null then
    select array_agg(distinct target order by target) into targets_ from unnest(p_target_ids) as target;
  end if;
  insert into public.push_jobs(id,title,body,target_ids) values(p_job_id,p_title,p_body,targets_) on conflict(id) do nothing;
  inserted_ := found;
  select * into item from public.push_jobs where id = p_job_id for update;
  if item.title <> p_title or item.body <> p_body or item.target_ids is distinct from targets_ then
    raise exception using errcode = 'PT409', message = 'request_conflict';
  end if;
  -- 최초 요청의 수신자와 토큰만 고정하여 같은 요청을 다시 보내도 중복 발송하지 않는다.
  if inserted_ then
    insert into public.push_deliveries(job_id,installation_id,token_hash)
      select p_job_id, installation_id, public.notification_token_hash(fcm_token) from public.push_tokens
      where enabled and fcm_token is not null and (targets_ is null or installation_id = any(targets_));
  end if;
  return public.notification_job_status(p_job_id);
end;
$$;

create function public.notification_claim(p_job_id uuid default null, p_limit integer default 5)
returns table(job_id uuid,installation_id uuid,claim_id uuid,fcm_token text,title text,body text,attempts integer)
language plpgsql security definer set search_path = '' as $$
declare candidate_ record; token_ text; claim_ uuid;
begin
  if p_limit is null or p_limit not between 1 and 5 then
    raise exception using errcode = 'PT400', message = 'invalid_request';
  end if;
  -- 발송 여부를 알 수 없는 만료 작업은 재전송하지 않아 중복 알림을 피한다.
  update public.push_deliveries d set status = 'unknown', updated_at = clock_timestamp()
    where d.status = 'sending' and d.updated_at <= clock_timestamp() - interval '5 minutes' and (p_job_id is null or d.job_id = p_job_id);
  update public.push_deliveries d set status = 'skipped', updated_at = clock_timestamp()
    from public.push_jobs j where d.job_id = j.id and d.status in ('pending','retry')
      and j.created_at <= clock_timestamp() - interval '24 hours' and (p_job_id is null or d.job_id = p_job_id);
  for candidate_ in
    select d.* from public.push_deliveries d where d.status in ('pending','retry')
      and d.available_at <= clock_timestamp() and (p_job_id is null or d.job_id = p_job_id)
      order by d.available_at, d.job_id, d.installation_id limit p_limit for update of d skip locked
  loop
    select t.fcm_token into token_ from public.push_tokens t where t.installation_id = candidate_.installation_id
      and t.enabled and public.notification_token_hash(t.fcm_token) = candidate_.token_hash;
    if token_ is null then
      update public.push_deliveries d set status = 'skipped', updated_at = clock_timestamp()
        where d.job_id = candidate_.job_id and d.installation_id = candidate_.installation_id;
      continue;
    end if;
    claim_ := gen_random_uuid();
    update public.push_deliveries d set status = 'sending', attempts = d.attempts + 1, claim_id = claim_, updated_at = clock_timestamp()
      where d.job_id = candidate_.job_id and d.installation_id = candidate_.installation_id;
    return query select j.id, candidate_.installation_id, claim_, token_, j.title, j.body, candidate_.attempts + 1
      from public.push_jobs j where j.id = candidate_.job_id;
  end loop;
end;
$$;

create function public.notification_delivery_current(p_job_id uuid,p_installation_id uuid,p_claim_id uuid)
returns boolean language plpgsql security definer set search_path = '' as $$
begin
  update public.push_deliveries set status = 'unknown', updated_at = clock_timestamp()
    where job_id = p_job_id and installation_id = p_installation_id and claim_id = p_claim_id
      and status = 'sending' and updated_at <= clock_timestamp() - interval '5 minutes';
  return exists(select 1 from public.push_deliveries d join public.push_tokens t on t.installation_id = d.installation_id
    where d.job_id = p_job_id and d.installation_id = p_installation_id and d.claim_id = p_claim_id and d.status = 'sending'
      and t.enabled and public.notification_token_hash(t.fcm_token) = d.token_hash);
end;
$$;

create function public.notification_finish(p_job_id uuid,p_installation_id uuid,p_claim_id uuid,p_outcome text,p_retry_seconds integer default 60)
returns boolean language plpgsql security definer set search_path = '' as $$
declare item public.push_deliveries; outcome_ text; delay_ integer;
begin
  if p_outcome is null or p_outcome not in ('sent','invalid','failed','skipped','unknown','retry')
    or p_retry_seconds is null or p_retry_seconds not between 1 and 86400 then
    raise exception using errcode = 'PT400', message = 'invalid_request';
  end if;
  select * into item from public.push_deliveries where job_id = p_job_id and installation_id = p_installation_id for update;
  if not found or item.status <> 'sending' or item.claim_id is distinct from p_claim_id then return false; end if;
  if item.updated_at <= clock_timestamp() - interval '5 minutes' then
    update public.push_deliveries set status = 'unknown', updated_at = clock_timestamp() where job_id = p_job_id and installation_id = p_installation_id;
    return false;
  end if;
  outcome_ := case when p_outcome = 'retry' and item.attempts >= 3 then 'failed' else p_outcome end;
  delay_ := greatest(p_retry_seconds, (60 * power(2, item.attempts - 1))::integer);
  update public.push_deliveries set status = outcome_, updated_at = clock_timestamp(),
    available_at = case when outcome_ = 'retry' then clock_timestamp() + make_interval(secs => delay_) else available_at end
    where job_id = p_job_id and installation_id = p_installation_id;
  -- 늦게 도착한 실패 결과가 새로 발급받은 토큰까지 지우지 않도록 비교한다.
  if outcome_ = 'invalid' then
    update public.push_tokens set fcm_token = null, enabled = false, updated_at = clock_timestamp()
      where installation_id = p_installation_id and public.notification_token_hash(fcm_token) = item.token_hash;
  end if;
  return true;
end;
$$;

revoke all on function public.notification_enqueue(uuid,text,text,uuid[]), public.notification_job_status(uuid), public.notification_claim(uuid,integer), public.notification_delivery_current(uuid,uuid,uuid), public.notification_finish(uuid,uuid,uuid,text,integer) from public, anon, authenticated, service_role;
grant execute on function public.notification_enqueue(uuid,text,text,uuid[]), public.notification_job_status(uuid), public.notification_claim(uuid,integer), public.notification_delivery_current(uuid,uuid,uuid), public.notification_finish(uuid,uuid,uuid,text,integer) to service_role;

commit;
