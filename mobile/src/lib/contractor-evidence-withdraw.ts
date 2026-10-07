import type {SupabaseClient} from '@supabase/supabase-js';
import {contractorWorkOffer} from './work-offers';
import {validId} from './catalog';
export async function withdrawContractorEvidence(client:SupabaseClient,owner:string,offer:string,id:string){
 if(!validId(id)||!await contractorWorkOffer(client,owner,offer))throw new Error('Assigned evidence required.');
 const read=async()=>{const r=await client.from('contractor_evidence').select('id,offer_id,user_id,state').eq('id',id).eq('offer_id',offer).eq('user_id',owner).maybeSingle();const d=r.data;if(r.error||!d||d.id!==id||d.offer_id!==offer||d.user_id!==owner||!['reserved','uploaded','withdrawn','expired'].includes(d.state))throw new Error('Evidence unavailable.');return d.state as string;};
 const before=await read();if(before!=='withdrawn'){const response=await client.rpc('withdraw_contractor_evidence',{p_evidence_id:id});if(response.error||response.data!==true)throw new Error('Evidence withdrawal could not be confirmed.');}
 if(await read()!=='withdrawn'||!await contractorWorkOffer(client,owner,offer))throw new Error('Recorded evidence withdrawal could not be confirmed.');return 'withdrawn' as const;
}
