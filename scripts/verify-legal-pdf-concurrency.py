"""Isolated Unix-socket fixture only. Storage metadata is simulated; no cloud credentials."""
import subprocess, pathlib, time, json, uuid

BASE=['psql','-X','-qAt','-h','/private/tmp/openhouse-finance-socket','-p','55439','-U','postgres','-v','ON_ERROR_STOP=1']
DB='openhouse_legal_pdf_concurrency'
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
    sql("""create schema storage;
    create table storage.buckets(id text primary key,name text,public boolean,file_size_limit bigint,allowed_mime_types text[]);
    create table storage.objects(id uuid primary key default gen_random_uuid(),bucket_id text references storage.buckets(id),name text,unique(bucket_id,name));
    alter table storage.objects enable row level security;
    grant usage on schema storage,private to authenticated,service_role;
    grant select,insert on storage.objects to authenticated,service_role;
    """)
    membership=pathlib.Path('supabase/migrations/20261007054101_audited_staff_membership.sql').read_text().replace('create function private.verified_staff_admin_organization()', 'create or replace function private.verified_staff_admin_organization()')
    sql('drop policy if exists "verified administrators read organization memberships" on public.staff_accounts;')
    sql(membership)
    sql('grant select on public.staff_accounts to authenticated;')
    sql(pathlib.Path('supabase/migrations/20261007024244_verified_staff_collaboration_reads.sql').read_text().split('alter policy')[0])
    for name in ['20261007040434_approved_lease_template_registry.sql','20261007104652_immutable_approved_lease_templates.sql','20261007104855_private_lease_template_documents.sql','20261007105315_lease_template_document_workflow.sql','20261007105740_lease_template_document_cleanup.sql']:
        sql(pathlib.Path('supabase/migrations',name).read_text())
    org='55667788-0000-4000-8000-000000000006';actor='55667788-0000-4000-8000-000000000020';other='55667788-0000-4000-8000-000000000021'
    sql("insert into auth.users(id,email,email_confirmed_at) values('"+actor+"','legal-admin@example.invalid',now()),('"+other+"','second-legal-admin@example.invalid',now());insert into public.organizations(id,name) values('"+org+"','Isolated legal fixture');insert into public.staff_accounts(user_id,organization_id,role) values('"+actor+"','"+org+"','admin'),('"+other+"','"+org+"','admin');")
    def identity(who=actor):return "select set_config('request.jwt.claim.sub','"+who+"',true);set local role authenticated;"
    admin=identity();service='set local role service_role;'
    def template(key):
        query="select public.register_approved_lease_template(gen_random_uuid(),'"+key+"',0,'Approved fixture','Approved business source fixture',repeat('a',64),true);"
        return json.loads(sql('begin;'+admin+query+'commit;').stdout.strip().splitlines()[-1])['id']
    def reserve(t,request):return "select public.reserve_lease_template_document('"+t+"','"+request+"','approved.pdf',100);"
    t=template('duplicate');request=str(uuid.uuid4())
    first=session('begin;'+admin+reserve(t,request)+'select pg_sleep(2);commit;');wait('PgSleep',first)
    second=session('begin;'+admin+reserve(t,request)+'commit;');wait('advisory',second)
    finish(first);finish(second)
    assert sql("select count(*) from public.lease_template_documents where template_id='"+t+"';").stdout.strip()=='1'
    first=session('begin;'+admin+reserve(t,request)+'select pg_sleep(2);commit;');wait('PgSleep',first)
    second=session('begin;'+admin+reserve(t,str(uuid.uuid4()))+'commit;');wait('advisory',second)
    finish(first);finish(second,'Template already has a document or active upload')
    doc=json.loads(sql('begin;'+admin+reserve(t,request)+'commit;').stdout.strip().splitlines()[-1])
    sql("insert into storage.objects(bucket_id,name) values('lease-template-documents','"+doc['path']+"');")
    certify="select public.finish_lease_template_document('"+actor+"','"+doc['id']+"',100,repeat('a',64));"
    first=session('begin;'+service+certify+'select pg_sleep(2);commit;');wait('PgSleep',first)
    second=session('begin;'+service+certify+'commit;');wait('advisory',second)
    finish(first);finish(second)
    assert sql("select count(*) from public.lease_template_document_events where document_id='"+doc['id']+"' and event_name='certified';").stdout.strip()=='1'
    # A withdrawal that commits first prevents service certification.
    withdrawn_template=template('withdrawal');withdrawn_request=str(uuid.uuid4())
    abandoned=json.loads(sql('begin;'+admin+reserve(withdrawn_template,withdrawn_request)+'commit;').stdout.strip().splitlines()[-1])
    sql("insert into storage.objects(bucket_id,name) values('lease-template-documents','"+abandoned['path']+"');")
    first=session('begin;'+admin+"select public.withdraw_lease_template_document('"+abandoned['id']+"');select pg_sleep(2);commit;");wait('PgSleep',first)
    second=session('begin;'+service+"select public.finish_lease_template_document('"+actor+"','"+abandoned['id']+"',100,repeat('a',64));commit;");wait('advisory',second)
    finish(first);finish(second,'Legal reservation unavailable')
    assert sql("select state from public.lease_template_documents where id='"+abandoned['id']+"';").stdout.strip()=='withdrawn'
    # Membership demotion commits while a reserving administrator is waiting.
    t2=template('revocation');demote="select public.manage_staff_membership(gen_random_uuid(),'legal-admin@example.invalid','manager',(select membership_revision from public.staff_accounts where user_id='"+actor+"'),'Approved fixture demotion',true);"
    first=session('begin;'+identity(other)+demote+'select pg_sleep(2);commit;');wait('PgSleep',first)
    second=session('begin;'+admin+reserve(t2,str(uuid.uuid4()))+'commit;');wait('advisory',second)
    finish(first);finish(second,'Administrator authority changed')
    assert sql("select count(*) from public.lease_template_documents where template_id='"+t2+"';").stdout.strip()=='0'
    # Restore through the membership workflow before isolated cleanup fixtures.
    promote=demote.replace("'manager'","'admin'").replace('demotion','restoration')
    sql('begin;'+identity(other)+promote+'commit;')
    sql("insert into public.lease_template_documents(template_id,organization_id,user_id,request_id,file_name,declared_size,object_path,expected_sha256,expires_at) select '"+t2+"','"+org+"','"+actor+"',gen_random_uuid(),'old.pdf',100,'fixture/cleanup/'||gen_random_uuid()::text||'.pdf',repeat('a',64),now()-interval '3 hours' from generate_series(1,10);")
    first=session('begin;'+service+'select count(*) from public.claim_expired_lease_template_document();select pg_sleep(2);commit;');wait('PgSleep',first)
    second=session('begin;'+service+'select count(*) from public.claim_expired_lease_template_document();commit;')
    assert finish(second).strip()=='0';assert first.poll() is None;finish(first)
    assert sql('select count(*) from private.lease_template_document_cleanup_claims;').stdout.strip()=='10'
    assert sql("select state from public.lease_template_documents where id='"+doc['id']+"';").stdout.strip()=='certified'
    print('PASS: observed duplicate/competing legal reservations, duplicate certification, administrator demotion and exclusive cleanup races (local PostgreSQL '+version+'; simulated Storage metadata)')
finally:
    for process in processes:
        if process.poll() is None:process.terminate();process.wait(timeout=5)
    sql('drop database '+DB+' with (force);','postgres')
