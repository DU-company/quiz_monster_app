begin;

alter table public.push_jobs add column scheduled_at timestamptz,
  add column started_at timestamptz,
  add column is_scheduled boolean not null default false,
  add column source text not null default 'legacy' check (source in ('legacy','dashboard'));
update public.push_jobs set scheduled_at = created_at, started_at = created_at;
alter table public.push_jobs alter column scheduled_at set not null,
  alter column scheduled_at set default clock_timestamp();
create index push_jobs_waiting on public.push_jobs(scheduled_at,id) where started_at is null;

create or replace function public.notification_job_status(p_job_id uuid)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare item public.push_jobs; counts_ jsonb; remaining_ integer; next_ timestamptz; state_ text;
begin
  select * into item from public.push_jobs where id = p_job_id;
  if not found then raise exception using errcode = 'PT404', message = 'job_not_found'; end if;
  select jsonb_object_agg(s.status, coalesce(c.total, 0)) into counts_
    from unnest(array['pending','retry','sending','sent','invalid','failed','skipped','unknown']) as s(status)
    left join (select status, count(*) total from public.push_deliveries where job_id = p_job_id group by status) c using (status);
  select count(*), min(case when status = 'sending' then updated_at + interval '5 minutes' else available_at end)
    into remaining_, next_ from public.push_deliveries where job_id = p_job_id and status in ('pending','retry','sending');
  state_ := case when item.started_at is null and item.scheduled_at <= clock_timestamp() - interval '24 hours' then 'expired'
    when item.started_at is null then 'waiting'
    when remaining_ > 0 then 'processing'
    else 'complete' end;
  return jsonb_build_object('job_id', p_job_id, 'title', item.title, 'body', item.body,
    'source', item.source, 'created_at', item.created_at, 'scheduled_at', item.scheduled_at,
    'started_at', item.started_at, 'is_scheduled', item.is_scheduled, 'state', state_, 'counts', counts_, 'remaining', remaining_,
    'next_attempt_at', case when state_ = 'waiting' then item.scheduled_at else next_ end);
end;
$$;

create or replace function public.notification_enqueue(p_job_id uuid, p_title text, p_body text, p_target_ids uuid[] default null)
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
  insert into public.push_jobs(id,title,body,target_ids,started_at) values(p_job_id,p_title,p_body,targets_,clock_timestamp()) on conflict(id) do nothing;
  inserted_ := found;
  select * into item from public.push_jobs where id = p_job_id for update;
  if item.source <> 'legacy' or item.title <> p_title or item.body <> p_body or item.target_ids is distinct from targets_ then
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

-- Distinct RPC avoids ambiguous PostgREST overloads and preserves the legacy signature.
create function public.notification_schedule(p_job_id uuid,p_title text,p_body text,p_target_ids uuid[],
  p_scheduled_at timestamptz,p_source text default 'dashboard')
returns jsonb language plpgsql security definer set search_path = '' as $$
declare targets_ uuid[]; item public.push_jobs; inserted_ boolean;
begin
  if p_job_id is null or p_title is null or length(p_title) not between 1 and 120 or octet_length(p_title)>480 or btrim(p_title)=''
    or p_body is null or length(p_body) not between 1 and 1000 or octet_length(p_body)>3000 or btrim(p_body)=''
    or (p_scheduled_at is not null and not isfinite(p_scheduled_at)) or p_source is distinct from 'dashboard'
    or (p_target_ids is not null and (cardinality(p_target_ids) not between 1 and 100 or array_position(p_target_ids,null) is not null)) then
    raise exception using errcode='PT400',message='invalid_request';
  end if;
  if p_target_ids is not null then
    select array_agg(distinct target order by target) into targets_ from unnest(p_target_ids) target;
  end if;
  insert into public.push_jobs(id,title,body,target_ids,scheduled_at,source,is_scheduled)
    values(p_job_id,p_title,p_body,targets_,coalesce(p_scheduled_at,clock_timestamp()),p_source,p_scheduled_at is not null) on conflict(id) do nothing;
  inserted_ := found;
  select * into item from public.push_jobs where id=p_job_id for update;
  if item.title<>p_title or item.body<>p_body or item.target_ids is distinct from targets_
    or item.is_scheduled<>(p_scheduled_at is not null)
    or (p_scheduled_at is not null and item.scheduled_at<>p_scheduled_at) or item.source<>p_source then
    raise exception using errcode='PT409',message='request_conflict';
  end if;
  -- Existing identical requests remain idempotent after their scheduled time.
  if inserted_ and p_scheduled_at <= clock_timestamp() then
    raise exception using errcode='PT400',message='scheduled_at_must_be_future';
  end if;
  return public.notification_job_status(p_job_id);
end;
$$;

create or replace function public.notification_claim(p_job_id uuid default null,p_limit integer default 5)
returns table(job_id uuid,installation_id uuid,claim_id uuid,fcm_token text,title text,body text,attempts integer)
language plpgsql security definer set search_path = '' as $$
declare candidate_ record; job_ record; token_ text; claim_ uuid;
begin
  if p_limit is null or p_limit not between 1 and 5 then
    raise exception using errcode='PT400',message='invalid_request';
  end if;
  -- A locked job owns its one-time recipient snapshot, including an empty snapshot.
  -- Expired unstarted jobs retain NULL started_at and never acquire recipients.
  for job_ in select j.* from public.push_jobs j
    where j.started_at is null and j.scheduled_at <= clock_timestamp()
      and j.scheduled_at > clock_timestamp()-interval '24 hours' and (p_job_id is null or j.id=p_job_id)
    order by j.scheduled_at,j.id limit 100 for update of j skip locked
  loop
    insert into public.push_deliveries(job_id,installation_id,token_hash)
      select job_.id,t.installation_id,public.notification_token_hash(t.fcm_token) from public.push_tokens t
      where t.enabled and t.fcm_token is not null and (job_.target_ids is null or t.installation_id=any(job_.target_ids));
    update public.push_jobs set started_at=clock_timestamp() where id=job_.id;
  end loop;
  update public.push_deliveries d set status='unknown',updated_at=clock_timestamp()
    where d.status='sending' and d.updated_at<=clock_timestamp()-interval '5 minutes' and (p_job_id is null or d.job_id=p_job_id);
  update public.push_deliveries d set status='skipped',updated_at=clock_timestamp()
    from public.push_jobs j where d.job_id=j.id and d.status in ('pending','retry')
      and j.scheduled_at<=clock_timestamp()-interval '24 hours' and (p_job_id is null or d.job_id=p_job_id);
  -- Round-robin slots plus least-recently-served jobs avoid a large campaign starving others.
  for candidate_ in
    with activity as (
      select d.job_id,max(d.updated_at) as last_served from public.push_deliveries d
      where d.attempts>0 or d.status<>'pending' group by d.job_id
    ), ranked as (
      select d.job_id,d.installation_id,j.scheduled_at,
        coalesce(a.last_served,'-infinity'::timestamptz) as last_served,
        row_number() over(partition by d.job_id order by d.available_at,d.installation_id) as slot
      from public.push_deliveries d join public.push_jobs j on j.id=d.job_id
      left join activity a on a.job_id=d.job_id
      where d.status in ('pending','retry') and d.available_at<=clock_timestamp()
        and j.started_at is not null and j.scheduled_at<=clock_timestamp()
        and j.scheduled_at>clock_timestamp()-interval '24 hours' and (p_job_id is null or d.job_id=p_job_id)
    )
    select d.* from ranked r join public.push_deliveries d using(job_id,installation_id)
      where d.status in ('pending','retry')
      order by r.slot,r.last_served,r.scheduled_at,d.job_id,d.installation_id limit p_limit for update of d skip locked
  loop
    select t.fcm_token into token_ from public.push_tokens t where t.installation_id=candidate_.installation_id
      and t.enabled and public.notification_token_hash(t.fcm_token)=candidate_.token_hash;
    if token_ is null then
      update public.push_deliveries d set status='skipped',updated_at=clock_timestamp()
        where d.job_id=candidate_.job_id and d.installation_id=candidate_.installation_id;
      continue;
    end if;
    claim_:=gen_random_uuid();
    update public.push_deliveries d set status='sending',attempts=d.attempts+1,claim_id=claim_,updated_at=clock_timestamp()
      where d.job_id=candidate_.job_id and d.installation_id=candidate_.installation_id;
    return query select j.id,candidate_.installation_id,claim_,token_,j.title,j.body,candidate_.attempts+1
      from public.push_jobs j where j.id=candidate_.job_id;
  end loop;
end;
$$;

create or replace function public.notification_delivery_current(p_job_id uuid,p_installation_id uuid,p_claim_id uuid)
returns boolean language plpgsql security definer set search_path = '' as $$
begin
  update public.push_deliveries set status = 'unknown', updated_at = clock_timestamp()
    where job_id = p_job_id and installation_id = p_installation_id and claim_id = p_claim_id
      and status = 'sending' and updated_at <= clock_timestamp() - interval '5 minutes';
  return exists(select 1 from public.push_deliveries d join public.push_tokens t on t.installation_id = d.installation_id
    where exists (select 1 from public.push_jobs j where j.id=d.job_id and j.scheduled_at<=clock_timestamp() and j.scheduled_at>clock_timestamp()-interval '24 hours')
      and d.job_id = p_job_id and d.installation_id = p_installation_id and d.claim_id = p_claim_id and d.status = 'sending'
      and t.enabled and public.notification_token_hash(t.fcm_token) = d.token_hash);
end;
$$;

revoke all on function public.notification_schedule(uuid,text,text,uuid[],timestamptz,text) from public,anon,authenticated,service_role;
grant execute on function public.notification_schedule(uuid,text,text,uuid[],timestamptz,text) to service_role;
commit;
