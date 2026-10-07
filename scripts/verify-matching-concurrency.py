"""Isolated Unix-socket fixture only. Matching preference migrations run against the isolated Auth fixture."""
import subprocess, pathlib, time, json, uuid

BASE=['psql','-X','-qAt','-h','/private/tmp/openhouse-finance-socket','-p','55439','-U','postgres','-v','ON_ERROR_STOP=1']
DB='openhouse_matching_concurrency'
processes=[]
def sql(query,db=DB,check=True):
    result=subprocess.run(BASE+['-d',db],input=query,text=True,capture_output=True)
    if check and result.returncode: raise AssertionError(result.stderr)
    return result
def session(query):
    process=subprocess.Popen(BASE+['-d',DB],stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True)
    processes.append(process);process.stdin.write(query);process.stdin.close();return process
def finish(process,error=None):
    process.wait(timeout=10);out=process.stdout.read();err=process.stderr.read()
    if error: assert process.returncode!=0 and error in err,err
    else: assert process.returncode==0,err
    return out
def wait(event,process=None):
    for _ in range(100):
        if process is not None and process.poll() is not None:
            raise AssertionError('Session ended before '+event+': '+process.stderr.read())
        if sql("select count(*) from pg_stat_activity where datname='"+DB+"' and wait_event='"+event+"';").stdout.strip()=='1': return
        time.sleep(.05)
    raise AssertionError('Expected independent-session wait was not observed: '+event)

assert sql('show listen_addresses;','postgres').stdout.strip()=='', 'Fixture must not listen on TCP'
version=sql('show server_version;','postgres').stdout.strip()
sql('create database '+DB+' template postgres;','postgres')
try:
    foundation=pathlib.Path('supabase/migrations/20261006151241_geo_realtor_matching.sql').read_text()
    sql(foundation[foundation.index('create table public.realtor_match_preferences'):])
    sql(pathlib.Path('supabase/migrations/20261007052640_verified_matching_preferences.sql').read_text())
    sql(pathlib.Path('supabase/migrations/20261007120739_matching_verification_lock.sql').read_text())
    actor='55667788-0000-4000-8000-000000000020'
    sql("insert into auth.users(id,email,email_confirmed_at) values('"+actor+"','matching-fixture@example.invalid',now());")
    identity="select set_config('request.jwt.claim.sub','"+actor+"',true);set local role authenticated;"
    preferences=json.dumps(dict(intent='buy',preferred_area='Kingston',communication_style='direct',guidance_style='data-led',decision_pace='considered'))
    def manage(action,revision=None):return "select public.manage_matching_preferences('"+action+"',"+("'"+revision+"'" if revision else 'null')+",'"+preferences+"'::jsonb,true);"
    def pair(first_query,second_query):
        first=session('begin;'+identity+first_query+'select pg_sleep(2);commit;');wait('PgSleep',first)
        second=session('begin;'+identity+second_query+'commit;');wait('advisory',second)
        finish(first);finish(second,'Preferences changed; refresh before retrying')
    pair(manage('save'),manage('save'))
    revision=sql("select revision from public.realtor_match_preferences where user_id='"+actor+"';").stdout.strip()
    pair(manage('save',revision),manage('delete',revision))
    revision=sql("select revision from public.realtor_match_preferences where user_id='"+actor+"';").stdout.strip()
    pair(manage('delete',revision),manage('save',revision))
    assert sql('select count(*) from public.realtor_match_preferences;').stdout.strip()=='0'
    # Verification removal commits while a request waits on its account lock.
    first=session("begin;select pg_advisory_xact_lock(hashtextextended('"+actor+"',89));update auth.users set email_confirmed_at=null where id='"+actor+"';select pg_sleep(2);commit;");wait('PgSleep',first)
    second=session('begin;'+identity+manage('save')+'commit;');wait('advisory',second)
    finish(first);finish(second,'Verified account required')
    assert sql('select count(*) from public.realtor_match_preferences;').stdout.strip()=='0'
    sql("update auth.users set email_confirmed_at=now() where id='"+actor+"';")
    first=session('begin;'+identity+manage('save')+'select pg_sleep(2);commit;');wait('PgSleep',first)
    second=session("begin;update auth.users set email_confirmed_at=null where id='"+actor+"';commit;");wait('transactionid',second)
    finish(first);finish(second)
    assert sql('select count(*) from public.realtor_match_preferences;').stdout.strip()=='1'
    print('PASS: observed competing initial saves, save/delete ordering and waiting verification-removal denial and save-first account-row protection (PostgreSQL '+version+')')
finally:
    for process in processes:
        if process.poll() is None:process.terminate();process.wait(timeout=5)
    sql('drop database '+DB+' with (force);','postgres')
