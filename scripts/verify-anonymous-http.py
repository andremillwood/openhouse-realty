"""Read-only anonymous gates against a separately started local application server."""
import argparse, urllib.request, urllib.error, urllib.parse
parser=argparse.ArgumentParser();parser.add_argument('--origin',default='http://127.0.0.1:3020');args=parser.parse_args()
origin=urllib.parse.urlsplit(args.origin)
assert origin.scheme=='http' and origin.hostname in ('127.0.0.1','localhost') and not origin.username and not origin.password and origin.path in ('','/') and not origin.query and not origin.fragment, 'Use a local application origin only'
class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self,*args,**kwargs):return None
opener=urllib.request.build_opener(urllib.request.ProxyHandler({}),NoRedirect)
paths=['/staff/reports/demand/compare?start=2026-10-01&end=2026-10-07','/staff/lease-reviews','/applications/77228899-0000-4000-8000-000000000001/lease/77228899-0000-4000-8000-000000000002','/applications/66117788-0000-4000-8000-000000000001/lease','/staff/leases/66117788-0000-4000-8000-000000000001','/staff/reports/demand','/staff/reports/maintenance','/staff/reports/contractors','/account/enquiries','/staff/preventive-plans','/staff/preventive-plans/44556600-0000-4000-8000-000000000001/skipped','/api/jobs/notifications']
for path in paths:
    try:response=opener.open(args.origin.rstrip('/')+path,timeout=15)
    except urllib.error.HTTPError as error:response=error
    code=response.code;location=response.headers.get('Location','');response.read();response.close()
    if path.startswith('/api/'):assert code==401,(path,code)
    else:assert code in (303,307,308) and '/sign-in' in location,(path,code,location)
    print('PASS anonymous HTTP gate',path,code)

for path in ['/api/viewings','/api/enquiries','/api/staff/lease-summaries','/api/lease-reviews']:
    request=urllib.request.Request(args.origin.rstrip('/')+path,data=b'{}',method='POST',headers={'Content-Type':'application/json','Origin':args.origin.rstrip('/')})
    try:response=opener.open(request,timeout=15)
    except urllib.error.HTTPError as error:response=error
    assert response.code==401,(path,response.code)
    assert response.headers.get('Cache-Control')=='private, no-store',(path,response.headers.get('Cache-Control'))
    response.read();response.close()
    print('PASS anonymous submission gate and private cache',path)
