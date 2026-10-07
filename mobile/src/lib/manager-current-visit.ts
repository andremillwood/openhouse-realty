import type {SupabaseClient} from '@supabase/supabase-js';
import {managerCurrentOffer} from './manager-current-offer';
import {managerAccess} from './manager-access';
import {validId} from './catalog';
export async function managerCurrentVisit(client:SupabaseClient,owner:string,work:string){
 const parent=await managerCurrentOffer(client,owner,work),access=await managerAccess(client,owner);if(!access)throw new Error('Management access required.');if(parent.offer?.state!=='accepted')return {parent,visit:null};
 const offer=parent.offer;const response=await client.from('contractor_visits').select('id,organization_id,offer_id,property_id,unit_id,state,version,starts_at,ends_at,shared_note').eq('organization_id',access.organization).eq('property_id',parent.work.propertyId).eq('offer_id',offer.id).in('state',['proposed','confirmed']).maybeSingle();if(response.error)throw new Error('Current appointment unavailable.');const r=response.data;
 if(r){const from=Date.parse(r.starts_at),until=Date.parse(r.ends_at);if(!validId(r.id)||r.organization_id!==access.organization||r.property_id!==parent.work.propertyId||r.unit_id!==parent.work.unit||r.offer_id!==offer.id||!['proposed','confirmed'].includes(r.state)||!Number.isInteger(r.version)||r.version<1||r.version>=2147483647||typeof r.starts_at!=='string'||typeof r.ends_at!=='string'||!Number.isFinite(from)||!Number.isFinite(until)||until<=from||until-from>8*60*60*1000||typeof r.shared_note!=='string'||r.shared_note.trim().length<5||r.shared_note.length>1000)throw new Error('Invalid appointment.');}
 const current=await managerAccess(client,owner),fresh=await managerCurrentOffer(client,owner,work);if(!current||current.organization!==access.organization||current.role!==access.role||current.revision!==access.revision||fresh.offer?.id!==offer.id||fresh.offer.state!=='accepted'||fresh.offer.version!==offer.version||fresh.work.version!==parent.work.version)throw new Error('Assignment changed.');
 return {parent:fresh,visit:r?{id:r.id as string,state:r.state as 'proposed'|'confirmed',version:r.version as number,starts:r.starts_at as string,ends:r.ends_at as string,note:r.shared_note as string}:null};
}
