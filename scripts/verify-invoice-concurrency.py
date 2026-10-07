"""Isolated Unix-socket fixture only. Storage metadata is simulated; no cloud credentials."""
import subprocess, pathlib, time, json

BASE=['psql','-X','-qAt','-h','/private/tmp/openhouse-finance-socket','-p','55439','-U','postgres','-v','ON_ERROR_STOP=1']
DB='openhouse_invoice_concurrency'
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
    for name in ['20261007084602_audited_vendor_invoice_review.sql','20261007090320_private_invoice_evidence.sql','20261007090728_invoice_evidence_state_guards.sql','20261007091010_invoice_evidence_upload_workflow.sql','20261007091829_invoice_review_evidence_snapshot.sql','20261007092523_invoice_evidence_cleanup.sql','20261007110654_approved_invoice_ledger_posting.sql']:
        sql(pathlib.Path('supabase/migrations',name).read_text())
    fixture=pathlib.Path('scripts/sql/verify-invoice-evidence-workflow.sql').read_text().split("select set_config('request.jwt.claim.sub'")[0]
    sql(fixture+'commit;')
    manager="select set_config('request.jwt.claim.sub','44556600-0000-4000-8000-000000000003',true);set local role authenticated;"
    finance=manager.replace('000000000003','000000000002')
    service='set local role service_role;'
    org='44556600-0000-4000-8000-000000000010';actor='44556600-0000-4000-8000-000000000003'
    def submit(number):
        return json.loads(sql('begin;'+manager+"select public.manage_vendor_invoice(gen_random_uuid(),'submit',null,0,null,null,'Fixture vendor','"+number+"',10001,'Approved fixture invoice',true);commit;").stdout.strip().splitlines()[-1])['id']
    invoice=submit('CONCURRENT-1')
    def reserve(inv,request):
        return "select public.reserve_invoice_evidence('"+inv+"','44556600-0000-4000-8000-"+request+"','invoice','invoice.pdf','application/pdf',100);"
    first=session('begin;'+manager+reserve(invoice,'000000000070')+'select pg_sleep(2);commit;');wait('PgSleep')
    second=session('begin;'+manager+reserve(invoice,'000000000070')+'commit;');wait('advisory')
    finish(first);finish(second)
    assert sql("select count(*) from public.vendor_invoice_evidence where request_id='44556600-0000-4000-8000-000000000070';").stdout.strip()=='1'
    assert sql("select count(*) from public.vendor_invoice_evidence_events where event_name='reserved';").stdout.strip()=='1'
    sql('begin;'+manager+"do $$ begin for n in 1..8 loop perform public.reserve_invoice_evidence('"+invoice+"',gen_random_uuid(),'supporting','support.pdf','application/pdf',100);end loop;end $$;commit;")
    first=session('begin;'+manager+reserve(invoice,'000000000071')+'select pg_sleep(2);commit;');wait('PgSleep')
    second=session('begin;'+manager+reserve(invoice,'000000000072')+'commit;');wait('advisory')
    finish(first);finish(second,'Invoice evidence upload limit reached')
    assert sql("select count(*) from public.vendor_invoice_evidence where invoice_id='"+invoice+"' and state='reserved';").stdout.strip()=='10'
    sql('begin;'+manager+"do $$ declare doc uuid;begin for doc in select id from public.vendor_invoice_evidence where state='reserved' loop perform public.withdraw_invoice_evidence(doc);end loop;end $$;commit;")
    def prepare(inv,request):
        doc=json.loads(sql('begin;'+manager+reserve(inv,request)+'commit;').stdout.strip().splitlines()[-1])
        sql("insert into storage.objects(bucket_id,name,metadata) values('vendor-invoice-evidence','"+doc['path']+"','{\"size\":100}');")
        return doc
    def certify(doc):
        return "select public.finish_invoice_evidence('"+actor+"','"+doc['id']+"',100,'application/pdf',repeat('a',64));"
    def review(inv):
        return "select public.manage_vendor_invoice(gen_random_uuid(),'review','"+inv+"',1,null,null,null,null,null,'Independent fixture review',true);"
    doc=prepare(invoice,'000000000073')
    first=session('begin;'+service+certify(doc)+'select pg_sleep(2);commit;');wait('PgSleep',first)
    second=session('begin;'+finance+review(invoice)+'commit;');wait('advisory')
    finish(first);finish(second)
    assert sql("select count(*) from public.vendor_invoice_review_evidence where invoice_id='"+invoice+"' and evidence_id='"+doc['id']+"' and sha256=repeat('a',64) and reviewed_version=2;").stdout.strip()=='1'
    invoice2=submit('CONCURRENT-2');doc2=prepare(invoice2,'000000000080');sql('begin;'+service+certify(doc2)+'commit;')
    first=session('begin;'+finance+review(invoice2)+'select pg_sleep(2);commit;');wait('PgSleep')
    second=session('begin;'+manager+"select public.withdraw_invoice_evidence('"+doc2['id']+"');commit;");wait('advisory')
    finish(first);finish(second,'Invoice evidence editing unavailable')
    assert sql("select state from public.vendor_invoice_evidence where id='"+doc2['id']+"';").stdout.strip()=='uploaded'
    invoice3=submit('CONCURRENT-CLEANUP')
    sql("insert into public.vendor_invoice_evidence(invoice_id,organization_id,user_id,request_id,kind,file_name,mime_type,declared_size,object_path,state,expires_at,withdrawn_at) select '"+invoice3+"','"+org+"','"+actor+"',gen_random_uuid(),'supporting','old.pdf','application/pdf',100,'fixture/old/'||gen_random_uuid()::text||'.pdf','withdrawn',now()-interval '3 hours',now()-interval '2 hours' from generate_series(1,10);")
    first=session('begin;'+service+'select count(*) from public.claim_expired_invoice_evidence();select pg_sleep(2);commit;');wait('PgSleep')
    # Cleanup deliberately skips busy organizations instead of waiting and duplicating claims.
    second=session('begin;'+service+'select count(*) from public.claim_expired_invoice_evidence();commit;')
    assert finish(second).strip()=='0';assert first.poll() is None
    finish(first)
    assert sql('begin;'+service+'select count(*) from public.claim_expired_invoice_evidence();commit;').stdout.strip()=='0'
    assert sql('select count(*) from private.invoice_evidence_cleanup_claims;').stdout.strip()=='10'
    assert sql("select count(*) from public.vendor_invoice_review_evidence;").stdout.strip()=='2'
    admin=manager.replace('000000000003','000000000001')
    sql("insert into public.finance_accounts(id,organization_id,code,name,account_class,approved_by,approval_reason) values('44556600-0000-4000-8000-000000000100','"+org+"','EXP-RACE','Expense fixture','expense','44556600-0000-4000-8000-000000000001','Approved fixture accounts'),('44556600-0000-4000-8000-000000000101','"+org+"','PAY-RACE','Payable fixture','liability','44556600-0000-4000-8000-000000000001','Approved fixture accounts');")
    def approve(inv):return "select public.manage_vendor_invoice(gen_random_uuid(),'approve','"+inv+"',2,null,null,null,null,null,'Independent approval fixture',true);"
    def post(inv,request):return "select public.post_approved_vendor_invoice('44556600-0000-4000-8000-"+request+"','"+inv+"',3,'44556600-0000-4000-8000-000000000100','44556600-0000-4000-8000-000000000101','Approved invoice accrual fixture',true);"
    # Posting waits for independent approval and observes the committed version.
    first=session('begin;'+admin+approve(invoice)+'select pg_sleep(2);commit;');wait('PgSleep',first)
    second=session('begin;'+finance+post(invoice,'000000000090')+'commit;');wait('advisory',second)
    finish(first);finish(second)
    # An exact retry returns the one retained journal after waiting.
    first=session('begin;'+finance+post(invoice,'000000000090')+'select pg_sleep(2);commit;');wait('PgSleep',first)
    second=session('begin;'+finance+post(invoice,'000000000090')+'commit;');wait('advisory',second)
    finish(first);finish(second)
    assert sql("select count(*) from public.vendor_invoice_ledger_postings where invoice_id='"+invoice+"';").stdout.strip()=='1'
    # Two different approvals to post the same invoice cannot create two journals.
    sql('begin;'+admin+approve(invoice2)+'commit;')
    first=session('begin;'+finance+post(invoice2,'000000000091')+'select pg_sleep(2);commit;');wait('PgSleep',first)
    second=session('begin;'+finance+post(invoice2,'000000000092')+'commit;');wait('advisory',second)
    finish(first);finish(second,'Only an unposted approved invoice can be posted')
    assert sql('select count(*) from public.vendor_invoice_ledger_postings;').stdout.strip()=='2'
    assert sql("select count(*) from (select p.invoice_id from public.vendor_invoice_ledger_postings p join public.finance_journal_lines l on l.journal_id=p.journal_id group by p.invoice_id having count(*)<>2 or sum(l.debit_minor)<>10001 or sum(l.credit_minor)<>10001) invalid;").stdout.strip()=='0'
    print('PASS: observed invoice reservation/quota/certification/review contention, frozen withdrawal denial and exclusive cleanup leases plus approval/posting, exact retry and competing ledger races (local PostgreSQL '+version+'; simulated Storage metadata)')
finally:
    for process in processes:
        if process.poll() is None: process.terminate();process.wait(timeout=5)
    sql('drop database '+DB+' with (force);','postgres')
