import type {SupabaseClient} from '@supabase/supabase-js';
import {applicantLeaseSummaryResult,leaseSummaryMoney,type ApplicantLeaseSummary} from '../../../lib/leases/summary';
import {validId} from './catalog';
import {verifiedSaveOwner} from './saves';
export {leaseSummaryMoney};
export async function applicantLeaseSummaries(client:SupabaseClient,owner:string,application:string,pageInput:number){
 if(!validId(application))throw new Error('Invalid application.');await verifiedSaveOwner(client,owner);
 const parent=await client.from('rental_applications').select('id').eq('id',application).eq('user_id',owner).maybeSingle();if(parent.error||parent.data?.id!==application)throw new Error('Application ownership required.');
 const requested=Math.min(100000,Math.max(1,Number.isSafeInteger(pageInput)?pageInput:1));
 const read=async(page:number)=>{const result=await client.rpc('applicant_lease_summaries',{p_application_id:application,p_page:page});if(result.error)throw new Error('Shared summaries unavailable.');return applicantLeaseSummaryResult(result.data);};
 let result=await read(requested);const pages=Math.max(1,Math.ceil(result.total/25)),page=Math.min(requested,pages);if(page!==requested)result=await read(page);if(page>Math.max(1,Math.ceil(result.total/25)))throw new Error("Shared summaries changed. Refresh to check.");
 const items:ApplicantLeaseSummary[]=result.items.map(r=>({id:r.id,version:r.version,state:r.state,starts_on:r.starts_on,ends_on:r.ends_on,billing_day:r.billing_day,rent_minor:r.rent_minor,deposit_minor:r.deposit_minor,property_name:r.property_name,unit_label:r.unit_label,template_title:r.template_title,released_at:r.released_at}));
 await verifiedSaveOwner(client,owner);return {total:result.total,pages:Math.max(1,Math.ceil(result.total/25)),page,items};
}
