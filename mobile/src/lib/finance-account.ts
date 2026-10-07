import type {SupabaseClient} from '@supabase/supabase-js';
import {financeAccess} from './finance-access';
import {validId} from './catalog';
export async function financeAccount(client:SupabaseClient,owner:string,id:string){
 if(!validId(id))throw Error('Valid account reference required.');const access=await financeAccess(client,owner);if(!access)throw Error('Approved finance membership required.');
 const response=await client.from('finance_accounts').select('id,organization_id,code,name,account_class').eq('id',id).eq('organization_id',access.organization).maybeSingle(),r=response.data;
 if(response.error||!r||r.id!==id||r.organization_id!==access.organization||typeof r.code!=='string'||!(/^[A-Z0-9][A-Z0-9._-]{0,39}$/).test(r.code)||typeof r.name!=='string'||r.name.trim().length<2||r.name.length>120||!['asset','liability','equity','income','expense'].includes(r.account_class))throw Error('Approved account unavailable.');
 const current=await financeAccess(client,owner);if(!current||current.organization!==access.organization||current.role!==access.role||current.revision!==access.revision)throw Error('Finance membership changed.');
 return {id,code:r.code as string,name:r.name as string,classification:r.account_class as string};
}
