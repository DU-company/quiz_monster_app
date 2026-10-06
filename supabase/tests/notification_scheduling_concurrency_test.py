"""Local Docker PostgreSQL only; requires the disposable DB and migrations already applied."""
import concurrent.futures
import json
import subprocess
import sys
import uuid

container, database = sys.argv[1:]
if not database.startswith('quiz_notifications_'):
    raise SystemExit('Requires disposable quiz_notifications_ database')

def sql(query):
    result = subprocess.run(['docker', 'exec', '-i', container, 'psql', '-U', 'postgres',
        '-d', database, '-v', 'ON_ERROR_STOP=1', '-Atq'], input=query, text=True,
        capture_output=True, check=True)
    return result.stdout.strip()

job = str(uuid.uuid4())
targets = [str(uuid.uuid4()) for _ in range(20)]
array = "array[" + ','.join("'%s'::uuid" % t for t in targets) + "]"
try:
    sql("insert into public.push_tokens(installation_id,credential_hash,fcm_token,enabled) values "
        + ','.join("('%s',repeat('a',64),'concurrency-%s',true)" % (t, t) for t in targets) + ';'
        + "select public.notification_schedule('%s','concurrent','body',%s,null);" % (job, array))
    def claim(_):
        # Holding locks lets the other worker exercise SKIP LOCKED under overlap.
        output = sql("begin; select coalesce(jsonb_agg(installation_id),'[]') from "
            "public.notification_claim('%s',5); select pg_sleep(0.2); commit;" % job)
        return json.loads(output.splitlines()[0])
    with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
        first = list(pool.map(claim, range(2)))
    # A worker may skip the still-locked initial snapshot. The next pair tests a started job.
    with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
        second = list(pool.map(claim, range(2)))
    claimed = [t for group in first + second for t in group]
    assert 10 <= len(claimed) <= 20
    assert len(set(claimed)) == len(claimed), 'duplicate delivery claimed'
    assert sql("select count(*) from public.push_deliveries where job_id='%s';" % job) == '20'
    assert sql("select started_at is not null from public.push_jobs where id='%s';" % job) == 't'
    assert sql("select max(attempts) from public.push_deliveries where job_id='%s';" % job) == '1'
    print('Concurrent snapshot and row claims passed: %d unique claims, 20 recipients exactly once' % len(claimed))
finally:
    sql("delete from public.push_deliveries where job_id='%s'; delete from public.push_jobs where id='%s'; "
        "delete from public.push_tokens where installation_id=any(%s);" % (job, job, array))
