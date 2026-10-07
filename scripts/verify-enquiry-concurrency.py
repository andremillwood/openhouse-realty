"""Isolated Unix-socket fixture only. Enquiry migrations run against a minimal Auth/catalog fixture."""
import subprocess, pathlib, time, json, uuid

BASE=['psql','-X','-qAt','-h','/private/tmp/openhouse-finance-socket','-p','55439','-U','postgres','-v','ON_ERROR_STOP=1']
DB='openhouse_enquiry_concurrency'
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

assert sql('show listen_addresses;','postgres').stdout.strip()==''
version=sql('show server_version;','postgres').stdout.strip()
sql('create database '+DB+' template postgres;','postgres')
try:
    sql("""create table public.listings(id uuid primary key,organization_id uuid,title text,status text);
    create table public.realtor_profiles(id uuid primary key,organization_id uuid,display_name text,is_published boolean);""")
    migration=pathlib.Path('supabase/migrations/20261007020759_enquiry_pipeline_and_notification_outbox.sql').read_text()
    sql(migration[:migration.index('-- Privileged internals')])
    baseline=pathlib.Path('supabase/migrations/20261007021438_stable_notification_payloads.sql').read_text()
    sql(baseline[:baseline.index('drop function public.claim_enquiry_notifications')])
    sql("""create function public.submit_enquiry(uuid,uuid,uuid,text,text,text,boolean) returns uuid language sql security invoker set search_path='' as $$select private.create_enquiry($1,$2,$3,$4,$5,$6,$7);$$;
    revoke all on function public.submit_enquiry(uuid,uuid,uuid,text,text,text,boolean) from public;
    grant execute on function public.submit_enquiry(uuid,uuid,uuid,text,text,text,boolean) to authenticated;""")
    sql(pathlib.Path('supabase/migrations/20261007122240_enquiry_verification_lock.sql').read_text())
    sql(pathlib.Path('supabase/migrations/20261007122617_enquiry_target_lock.sql').read_text())
    actor='77990011-0000-4000-8000-000000000020';target='77990011-0000-4000-8000-000000000021';org='77990011-0000-4000-8000-000000000022';request='77990011-0000-4000-8000-000000000023'
    sql("insert into auth.users(id,email,email_confirmed_at) values('"+actor+"','enquiry-fixture@example.invalid',now());insert into public.organizations(id,name) values('"+org+"','Enquiry fixture');insert into public.listings values('"+target+"','"+org+"','Fixture listing','published');")
    identity="select set_config('request.jwt.claim.sub','"+actor+"',true);set local role authenticated;"
    intake="select public.submit_enquiry('"+request+"','"+target+"',null,'Fixture Client','','Please contact me about this listing.',true);"
    first=session('begin;'+identity+intake+'select pg_sleep(2);commit;');wait('PgSleep',first)
    second=session('begin;'+identity+intake+'commit;');wait('advisory',second)
    finish(first);finish(second)
    assert sql('select count(*) from public.enquiries;').stdout.strip()=='1'
    assert sql('select count(*) from private.notification_outbox;').stdout.strip()=='1'
    sql('truncate private.notification_outbox,public.enquiry_events,public.enquiries;')
    first=session("begin;select pg_advisory_xact_lock(hashtextextended('"+actor+"',42));update auth.users set email_confirmed_at=null where id='"+actor+"';select pg_sleep(2);commit;");wait('PgSleep',first)
    second=session('begin;'+identity+intake+'commit;');wait('advisory',second)
    finish(first);finish(second,'Verified email required')
    assert sql('select count(*) from public.enquiries;').stdout.strip()=='0'
    assert sql("select email_confirmed_at is null from auth.users where id='"+actor+"';").stdout.strip()=='t'
    sql("update auth.users set email_confirmed_at=now() where id='"+actor+"';")
    first=session('begin;'+identity+intake+'select pg_sleep(2);commit;');wait('PgSleep',first)
    second=session("begin;update auth.users set email_confirmed_at=null where id='"+actor+"';commit;");wait('transactionid',second)
    finish(first);finish(second)
    assert sql('select count(*) from public.enquiries;').stdout.strip()=='1'
    assert sql('select count(*) from private.notification_outbox;').stdout.strip()=='1'
    sql("update auth.users set email_confirmed_at=now() where id='"+actor+"';truncate private.notification_outbox,public.enquiry_events,public.enquiries;")
    # Four submissions leave one place in the hourly allowance.
    for index in range(4):
        sql('begin;'+identity+intake.replace(request,str(uuid.uuid4()))+'commit;')
    first=session('begin;'+identity+intake+'select pg_sleep(2);commit;');wait('PgSleep',first)
    second=session('begin;'+identity+intake.replace(request,str(uuid.uuid4()))+'commit;');wait('advisory',second)
    finish(first);finish(second,'Enquiry rate limit reached')
    assert sql('select count(*) from public.enquiries;').stdout.strip()=='5'
    assert sql('select count(*) from private.notification_outbox;').stdout.strip()=='5'
    assert sql('select count(*) from public.enquiry_events;').stdout.strip()=='5'
    sql('truncate private.notification_outbox,public.enquiry_events,public.enquiries;')
    sql("insert into public.realtor_profiles values('"+target+"','"+org+"','Fixture Realtor',true);")
    realtor_intake=intake.replace("'"+target+"',null","null,'"+target+"'")
    for table,published,unpublished,query in [('listings',"status='published'","status='paused'",intake),('realtor_profiles','is_published=true','is_published=false',realtor_intake)]:
        change="update public."+table+" set "+unpublished+" where id='"+target+"';"
        first=session('begin;'+change+'select pg_sleep(2);commit;');wait('PgSleep',first)
        second=session('begin;'+identity+query+'commit;');wait('transactionid',second)
        finish(first);finish(second,'Target unavailable')
        assert sql('select count(*) from public.enquiries;').stdout.strip()=='0'
        assert sql('select count(*) from private.notification_outbox;').stdout.strip()=='0'
        sql("update public."+table+" set "+published+" where id='"+target+"';")
        first=session('begin;'+identity+query+'select pg_sleep(2);commit;');wait('PgSleep',first)
        second=session('begin;'+change+'commit;');wait('transactionid',second)
        finish(first);finish(second)
        assert sql('select count(*) from public.enquiries;').stdout.strip()=='1'
        # Exact recovery after unpublication remains the original submission.
        sql('begin;'+identity+query+'commit;')
        assert sql('select count(*) from public.enquiries;').stdout.strip()=='1'
        assert sql('select count(*) from private.notification_outbox;').stdout.strip()=='1'
        sql('truncate private.notification_outbox,public.enquiry_events,public.enquiries;')
    print('PASS: duplicate retry, both verification orders, final hourly quota and both listing/realtor unpublication orders with exact retry recovery (isolated PostgreSQL '+version+')')

finally:
    for process in processes:
        if process.poll() is None:process.terminate();process.wait(timeout=5)
    sql('drop database '+DB+' with (force);','postgres')
