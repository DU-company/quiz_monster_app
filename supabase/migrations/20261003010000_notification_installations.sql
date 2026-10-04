begin;

-- 고정 UTF-8 변환으로 토큰 해시를 인덱스에서 재현 가능하게 계산한다.
create function public.notification_token_hash(p_token text)
returns bytea language sql immutable strict parallel safe set search_path = '' as $$
  select pg_catalog.sha256(pg_catalog.convert_to(p_token, 'UTF8'));
$$;
revoke all on function public.notification_token_hash(text) from public, anon, authenticated, service_role;

create table public.push_tokens (
  installation_id uuid primary key,
  credential_hash text not null check (credential_hash ~ '^[0-9a-f]{64}$'),
  fcm_token text check (fcm_token is null or (length(fcm_token) between 1 and 4096 and btrim(fcm_token) <> '')),
  enabled boolean not null default false,
  revision bigint not null default 0 check (revision between 0 and 9007199254740991),
  updated_at timestamptz not null default now()
);
-- 긴 토큰도 인덱스 크기 제한 없이 중복을 막는다.
create unique index push_tokens_token_unique on public.push_tokens (public.notification_token_hash(fcm_token)) where fcm_token is not null;
create index push_tokens_active on public.push_tokens (installation_id) where enabled and fcm_token is not null;
alter table public.push_tokens enable row level security;
revoke all on public.push_tokens from public, anon, authenticated, service_role;

create table public.push_token_rate_limits (
  bucket text primary key check (length(bucket) between 1 and 200),
  hits integer not null check (hits > 0),
  expires_at timestamptz not null
);
create index push_token_rate_limits_expiry on public.push_token_rate_limits (expires_at);
alter table public.push_token_rate_limits enable row level security;
revoke all on public.push_token_rate_limits from public, anon, authenticated, service_role;

create function public.notification_register(p_installation_id uuid, p_credential_hash text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare item public.push_tokens;
begin
  if p_installation_id is null or p_credential_hash is null or p_credential_hash !~ '^[0-9a-f]{64}$' then
    raise exception using errcode = 'PT400', message = 'invalid_request';
  end if;
  insert into public.push_tokens (installation_id, credential_hash)
    values (p_installation_id, p_credential_hash) on conflict (installation_id) do nothing;
  select * into item from public.push_tokens where installation_id = p_installation_id for update;
  if item.credential_hash <> p_credential_hash then
    raise exception using errcode = 'PT401', message = 'installation_auth_failed';
  end if;
  return jsonb_build_object('revision', item.revision, 'enabled', item.enabled);
end;
$$;

create function public.notification_sync(p_installation_id uuid, p_credential_hash text, p_revision bigint, p_enabled boolean, p_fcm_token text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare item public.push_tokens;
begin
  if p_installation_id is null or p_credential_hash is null or p_credential_hash !~ '^[0-9a-f]{64}$' or p_revision is null or p_revision not between 0 and 9007199254740991 or p_enabled is null or (p_fcm_token is not null and (length(p_fcm_token) not between 1 and 4096 or btrim(p_fcm_token) = '')) then
    raise exception using errcode = 'PT400', message = 'invalid_request';
  end if;
  select * into item from public.push_tokens where installation_id = p_installation_id for update;
  if not found or item.credential_hash <> p_credential_hash then
    raise exception using errcode = 'PT401', message = 'installation_auth_failed';
  end if;
  if p_revision < item.revision or (p_revision = item.revision and (item.enabled <> p_enabled or item.fcm_token is distinct from p_fcm_token)) then
    raise exception using errcode = 'PT409', message = 'revision_conflict';
  end if;
  update public.push_tokens set revision = p_revision, enabled = p_enabled,
    fcm_token = p_fcm_token, updated_at = clock_timestamp()
    where installation_id = p_installation_id returning * into item;
  return jsonb_build_object('revision', item.revision, 'enabled', item.enabled);
exception when unique_violation then
  raise exception using errcode = 'PT409', message = 'token_conflict';
end;
$$;

create function public.notification_invalidate_token(p_installation_id uuid, p_fcm_token text)
returns boolean language plpgsql security definer set search_path = '' as $$
begin
  -- 실패한 토큰이 현재 값일 때만 지워 늦은 발송 결과가 새 토큰을 해제하지 않게 한다.
  update public.push_tokens set fcm_token = null, enabled = false, updated_at = clock_timestamp()
    where installation_id = p_installation_id and fcm_token = p_fcm_token;
  return found;
end;
$$;

create function public.notification_active_tokens()
returns table (installation_id uuid, fcm_token text) language sql stable security definer set search_path = '' as $$
  select installation_id, fcm_token from public.push_tokens where enabled and fcm_token is not null;
$$;

create function public.notification_take_rate_limit(p_bucket text, p_limit integer, p_window_seconds integer default 60)
returns boolean language plpgsql security definer set search_path = '' as $$
declare used integer; current_time_ timestamptz := clock_timestamp();
begin
  if p_bucket is null or length(p_bucket) not between 1 and 200 or p_limit is null or p_limit not between 1 and 1000000 or p_window_seconds is null or p_window_seconds not between 1 and 86400 then
    raise exception using errcode = 'PT400', message = 'invalid_rate_limit';
  end if;
  delete from public.push_token_rate_limits where bucket in (
    select bucket from public.push_token_rate_limits where expires_at <= current_time_ order by expires_at limit 100 for update skip locked
  );
  -- 경쟁 요청에서도 제한 개수를 넘는 호출은 카운터 갱신 없이 거절한다.
  insert into public.push_token_rate_limits as limits (bucket, hits, expires_at)
    values (p_bucket, 1, current_time_ + make_interval(secs => p_window_seconds))
    on conflict (bucket) do update set
      hits = case when limits.expires_at <= current_time_ then 1 else limits.hits + 1 end,
      expires_at = case when limits.expires_at <= current_time_ then excluded.expires_at else limits.expires_at end
      where limits.expires_at <= current_time_ or limits.hits < p_limit
    returning hits into used;
  return used is not null;
end;
$$;

revoke all on function public.notification_register(uuid,text), public.notification_sync(uuid,text,bigint,boolean,text), public.notification_invalidate_token(uuid,text), public.notification_active_tokens(), public.notification_take_rate_limit(text,integer,integer) from public, anon, authenticated, service_role;
grant execute on function public.notification_register(uuid,text), public.notification_sync(uuid,text,bigint,boolean,text), public.notification_invalidate_token(uuid,text), public.notification_active_tokens(), public.notification_take_rate_limit(text,integer,integer) to service_role;

commit;
