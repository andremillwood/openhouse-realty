import type {SupabaseClient} from '@supabase/supabase-js';
import {managerWorkDetail} from './manager-work-detail';
import {managerAccess} from './manager-access';
import {validId} from './catalog';
export async function managerCurrentOffer(client:SupabaseClient,owner:string,workId:string){
 const work=await managerWorkDetail(client,owner,workId),access=await managerAccess(client,owner);if(!work||!access)throw new Error('Approved work access required.');
 const response=await client.from('contractor_work_offers').select('id,organization_id,work_order_id,contractor_id,job_title,scope_summary,company_name_snapshot,trade,state,version,expires_at').eq('organization_id',access.organization).eq('work_order_id',workId).in('state',['offered','accepted']).maybeSingle();if(response.error)throw new Error('Current offer unavailable.');const r=response.data;
 if(r&&(!validId(r.id)||r.organization_id!==access.organization||r.work_order_id!==workId||!validId(r.contractor_id)||!['offered','accepted'].includes(r.state)||!Number.isInteger(r.version)||r.version<1||r.version>=2147483647||typeof r.expires_at!=='string'||!Number.isFinite(Date.parse(r.expires_at))||([['job_title',3,160],['scope_summary',20,3000],['company_name_snapshot',2,160],['trade',1,80]] as const).some(([k,min,max])=>typeof r[k]!=='string'||r[k].trim().length<min||r[k].length>max)))throw new Error('Invalid current offer.');
 const current=await managerAccess(client,owner),currentWork=await managerWorkDetail(client,owner,workId);if(!current||current.organization!==access.organization||current.role!==access.role||current.revision!==access.revision||!currentWork||currentWork.version!==work.version)throw new Error('Work access or revision changed.');
 return {work:currentWork,offer:r?{id:r.id as string,contractor:r.contractor_id as string,title:r.job_title as string,scope:r.scope_summary as string,company:r.company_name_snapshot as string,trade:r.trade as string,state:r.state as 'offered'|'accepted',version:r.version as number,expires:r.expires_at as string,expired:r.state==='offered'&&Date.parse(r.expires_at)<=Date.now()}:null};
}
