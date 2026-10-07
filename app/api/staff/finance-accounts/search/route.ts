import {NextRequest, NextResponse} from 'next/server';
import {catalogAccess} from '@/lib/staff/access';
const headers={'Cache-Control':'private, no-store'};
export async function GET(request: NextRequest) {
  const {client, user, membership} = await catalogAccess(['admin', 'finance']);
  if (!user) return NextResponse.json({error: 'Verified sign-in required.'}, {status: 401,headers});
  if (!membership) return NextResponse.json({error: 'Organization finance access required.'}, {status: 403,headers});
  const params = new URL(request.url).searchParams;
  const term = (params.get('q') || '').trim(), field = params.get('field') || 'code';
  if (term.length > 120 || !['code', 'name'].includes(field)) return NextResponse.json({error: 'Check the search term.'}, {status: 400,headers});
  const rawClasses=params.get('classes'),classes=rawClasses===null?[]:rawClasses.split(',');
  if(params.getAll('classes').length>1||classes.length>5||new Set(classes).size!==classes.length||classes.some(value=>!['asset','liability','equity','income','expense'].includes(value)))return NextResponse.json({error:'Choose valid account classifications.'},{status:400,headers});
  const literal = term.replace(/[\\%_]/g, '\\$&');
  let query=client.from('finance_accounts').select('id,code,name,account_class').eq('organization_id',membership.organization_id);
  if(classes.length)query=query.in('account_class',classes);
  const {data,error}=await query.ilike(field,`%${literal}%`).order('code').order('id').limit(26);
  if (error) return NextResponse.json({error: 'Unable to search approved accounts.'}, {status: 503,headers});
  return NextResponse.json({accounts: (data || []).slice(0, 25), more: (data || []).length > 25}, {headers});
}
