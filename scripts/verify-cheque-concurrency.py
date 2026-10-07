"""Isolated Unix-socket fixture only. Storage metadata is simulated; no cloud credentials."""
import subprocess, pathlib, time, json, uuid

BASE=['psql','-X','-qAt','-h','/private/tmp/openhouse-finance-socket','-p','55439','-U','postgres','-v','ON_ERROR_STOP=1']
DB='openhouse_cheque_concurrency'
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
    # The earlier finance fixture has finance/Auth schemas. These unused dependencies
    # are minimal metadata fixtures; allocation and real Storage are verified elsewhere.
    sql("""create schema storage;
    create table storage.buckets(id text primary key,name text,public boolean,file_size_limit bigint,allowed_mime_types text[]);
    create table storage.objects(id uuid primary key default gen_random_uuid(),bucket_id text references storage.buckets(id),name text,metadata jsonb,owner_id text,unique(bucket_id,name));
    alter table storage.objects enable row level security;
    grant usage on schema storage to authenticated,service_role;
    grant select,insert,update,delete on storage.objects to authenticated,service_role;
    grant usage on schema private to service_role;
    create table public.work_orders(id uuid primary key default gen_random_uuid(),organization_id uuid references public.organizations(id),property_id uuid references public.properties(id),title text,revision integer default 1,status text);
    """)
    for name in ['20261007100613_audited_cheque_custody.sql','20261007101311_private_cheque_bank_evidence.sql','20261007101351_cheque_evidence_state_guards.sql','20261007101517_cheque_evidence_upload_workflow.sql','20261007102327_frozen_cheque_bank_evidence.sql','20261007102540_controlled_cheque_bank_transitions.sql','20261007103008_cheque_evidence_cleanup.sql','20261007103744_controlled_cheque_ledger_posting.sql']:
        sql(pathlib.Path('supabase/migrations',name).read_text())
    fixture=pathlib.Path('scripts/sql/verify-cheque-evidence-workflow.sql').read_text().split("select set_config('request.jwt.claim.sub'")[0]
    sql(fixture+'commit;')
    finance="select set_config('request.jwt.claim.sub','44556600-0000-4000-8000-000000000002',true);set local role authenticated;"
    service='set local role service_role;'
    org='44556600-0000-4000-8000-000000000010';actor='44556600-0000-4000-8000-000000000002';cheque='44556600-0000-4000-8000-000000000030'
    def reserve(request):
        return "select public.reserve_cheque_evidence('"+cheque+"','44556600-0000-4000-8000-"+request+"','deposit','bank.pdf','application/pdf',100);"
    first=session('begin;'+finance+reserve('000000000070')+'select pg_sleep(2);commit;');wait('PgSleep',first)
    second=session('begin;'+finance+reserve('000000000070')+'commit;');wait('advisory',second)
    finish(first);finish(second)
    assert sql("select count(*) from public.cheque_bank_evidence where request_id='44556600-0000-4000-8000-000000000070';").stdout.strip()=='1'
    doc=json.loads(sql('begin;'+finance+reserve('000000000070')+'commit;').stdout.strip().splitlines()[-1])
    sql("insert into storage.objects(bucket_id,name) values('cheque-bank-evidence','"+doc['path']+"');")
    certify="select public.finish_cheque_evidence('"+actor+"','"+doc['id']+"',100,'application/pdf',repeat('a',64));"
    def deposit(request):
        return "select public.manage_cheque_custody('44556600-0000-4000-8000-"+request+"','record_deposit','"+cheque+"',1,null,null,null,null,null,'"+doc['id']+"','BANK-CONCURRENT','Approved concurrent deposit',true);"
    first=session('begin;'+service+certify+'select pg_sleep(2);commit;');wait('PgSleep',first)
    second=session('begin;'+finance+deposit('000000000080')+'commit;');wait('advisory',second)
    finish(first);finish(second)
    assert sql("select count(*) from public.cheque_bank_evidence_snapshots where evidence_id='"+doc['id']+"' and decision_version=2;").stdout.strip()=='1'
    # Exact retry waits for the same organization lock and returns the one audited result.
    first=session('begin;'+finance+deposit('000000000080')+'select pg_sleep(2);commit;');wait('PgSleep',first)
    second=session('begin;'+finance+deposit('000000000080')+'commit;');wait('advisory',second)
    finish(first);finish(second)
    assert sql("select count(*) from public.cheque_custody_events where request_id='44556600-0000-4000-8000-000000000080';").stdout.strip()=='1'
    # Independent stale approval and withdrawal are rejected after observing committed custody.
    first=session('begin;'+finance+deposit('000000000080')+'select pg_sleep(2);commit;');wait('PgSleep',first)
    second=session('begin;'+finance+deposit('000000000081')+'commit;');wait('advisory',second)
    finish(first);finish(second,'Cheque changed; refresh')
    first=session('begin;'+finance+deposit('000000000080')+'select pg_sleep(2);commit;');wait('PgSleep',first)
    second=session('begin;'+finance+"select public.withdraw_cheque_evidence('"+doc['id']+"');commit;");wait('advisory',second)
    finish(first);finish(second,'Audited bank evidence is frozen')
    assert sql("select state from public.cheque_bank_evidence where id='"+doc['id']+"';").stdout.strip()=='uploaded'
    sql("insert into public.cheque_bank_evidence(cheque_id,organization_id,user_id,request_id,kind,file_name,mime_type,declared_size,object_path,state,expires_at,withdrawn_at) select '"+cheque+"','"+org+"','"+actor+"',gen_random_uuid(),'return','old.pdf','application/pdf',100,'fixture/old/'||gen_random_uuid()::text||'.pdf','withdrawn',now()-interval '3 hours',now()-interval '2 hours' from generate_series(1,10);")
    first=session('begin;'+service+'select count(*) from public.claim_expired_cheque_evidence();select pg_sleep(2);commit;');wait('PgSleep',first)
    second=session('begin;'+service+'select count(*) from public.claim_expired_cheque_evidence();commit;')
    assert finish(second).strip()=='0';assert first.poll() is None;finish(first)
    assert sql('select count(*) from private.cheque_evidence_cleanup_claims;').stdout.strip()=='10'
    assert sql('select count(*) from public.cheque_bank_evidence_snapshots;').stdout.strip()=='1'
    debit=str(uuid.uuid4());credit=str(uuid.uuid4())
    sql("insert into public.finance_accounts(id,organization_id,code,name,account_class,approved_by,approval_reason) values('"+debit+"','"+org+"','BANK-RACE','Bank fixture','asset','44556600-0000-4000-8000-000000000001','Approved race account'),('"+credit+"','"+org+"','CONTRA-RACE','Contra fixture','liability','44556600-0000-4000-8000-000000000001','Approved race account');")
    def bank_action(target,action,revision,evidence):
        return "select public.manage_cheque_custody(gen_random_uuid(),'"+action+"','"+target+"',"+str(revision)+",null,null,null,null,null,'"+evidence+"','BANK-RACE','Approved race bank decision',true);"
    def ready():
        target=str(uuid.uuid4());documents=[str(uuid.uuid4()) for _ in range(3)]
        sql("insert into public.audited_cheque_receipts(id,organization_id,property_id,payer_name,bank_name,cheque_reference,amount_minor,received_by) values('"+target+"','"+org+"','44556600-0000-4000-8000-000000000020','Race payer','Race bank','"+target+"',10001,'"+actor+"');")
        for doc_id,kind in zip(documents,['deposit','clearance','return']):
            sql("insert into public.cheque_bank_evidence(id,cheque_id,organization_id,user_id,request_id,kind,file_name,mime_type,declared_size,object_path,state,sha256,actual_size,uploaded_at) values('"+doc_id+"','"+target+"','"+org+"','"+actor+"',gen_random_uuid(),'"+kind+"','bank.pdf','application/pdf',100,'race/"+doc_id+"','uploaded',repeat('a',64),100,now());")
        sql('begin;'+finance+bank_action(target,'record_deposit',1,documents[0])+bank_action(target,'confirm_clear',2,documents[1])+'commit;')
        return target,documents[2]
    def post(target,request):
        return "select public.post_cleared_cheque('"+request+"','"+target+"',3,'"+debit+"','"+credit+"','Approved race accounting',true);"
    for order in ['posting_first','return_first','same_request']:
        target,returned=ready();request=str(uuid.uuid4());posting=post(target,request);returning=bank_action(target,'record_return',3,returned)
        first_query=returning if order=='return_first' else posting
        second_query=posting if order!='posting_first' else returning
        first=session('begin;'+finance+first_query+'select pg_sleep(2);commit;');wait('PgSleep',first)
        second=session('begin;'+finance+second_query+'commit;');wait('advisory',second)
        finish(first);finish(second,'Cheque changed; refresh' if order=='return_first' else None)
        count=sql("select count(*) from public.cheque_ledger_postings where cheque_id='"+target+"';").stdout.strip()
        assert count==('0' if order=='return_first' else '1'),order
        if order=='same_request':
            assert sql("select count(*) from public.finance_journals where posted_by='"+actor+"' and request_id='"+request+"';").stdout.strip()=='1'
            sql('begin;'+finance+returning+'commit;')
        if order!='return_first':
            assert sql("select count(*) from public.cheque_ledger_postings p join public.finance_journal_reversals r on r.original_journal_id=p.journal_id where p.cheque_id='"+target+"';").stdout.strip()=='1'
            assert sql("select count(*) from (select l.account_id from public.finance_journal_lines l join public.cheque_ledger_postings p on p.cheque_id='"+target+"' join public.finance_journal_reversals r on r.original_journal_id=p.journal_id where l.journal_id in(p.journal_id,r.reversal_journal_id) group by l.account_id having sum(l.debit_minor)<>sum(l.credit_minor)) imbalance;").stdout.strip()=='0'
    print('PASS: observed cheque evidence/custody/cleanup contention plus posting-first, return-first and duplicate ledger request races (local PostgreSQL '+version+'; simulated Storage metadata)')
finally:
    for process in processes:
        if process.poll() is None: process.terminate();process.wait(timeout=5)
    sql('drop database '+DB+' with (force);','postgres')
