import type {SupabaseClient} from '@supabase/supabase-js';
import {listingProjection,publicListing,validId,type Listing} from './catalog';
export async function verifiedSaveOwner(client:SupabaseClient,expected:string){
 const {data,error}=await client.auth.getUser();
 if(error||!data.user?.email_confirmed_at||data.user.id!==expected)throw new Error('Verify your account before managing saved properties.');
 return data.user.id;
}
export async function savedStatus(client:SupabaseClient,owner:string,listing:string){
 if(!validId(listing))throw new Error('Invalid property');await verifiedSaveOwner(client,owner);
 const {data,error}=await client.from('saved_listings').select('listing_id').eq('user_id',owner).eq('listing_id',listing).maybeSingle();
 if(error||(data!==null&&(!data||typeof data!=='object'||Array.isArray(data)||data.listing_id!==listing)))throw new Error('Unable to check saved status');
 await verifiedSaveOwner(client,owner);return !!data;
}
export async function setSaved(client:SupabaseClient,owner:string,listing:string,desired:boolean){
 if(!validId(listing)||typeof desired!=='boolean')throw new Error('Invalid save');await verifiedSaveOwner(client,owner);
 const result=desired?await client.from('saved_listings').upsert({user_id:owner,listing_id:listing},{onConflict:'user_id,listing_id',ignoreDuplicates:true}):await client.from('saved_listings').delete().eq('user_id',owner).eq('listing_id',listing);
 if(result.error)throw new Error('Unable to confirm saved change');
 const confirmed=await savedStatus(client,owner,listing);if(confirmed!==desired)throw new Error('Saved status changed while confirming');return confirmed;
}
export async function savedProperties(client:SupabaseClient,owner:string,inputPage:number){
 await verifiedSaveOwner(client,owner);
 const countResult=await client.from('saved_listings').select('listing_id',{head:true,count:'exact'}).eq('user_id',owner);
 if(countResult.error||!Number.isSafeInteger(countResult.count)||countResult.count!<0)throw new Error('Unable to load saved properties');
 const total=countResult.count!,pages=Math.max(1,Math.ceil(total/24)),page=Math.min(Math.max(1,Number.isSafeInteger(inputPage)?inputPage:1),pages);
 if(!total){await verifiedSaveOwner(client,owner);return {total,pages,page,rows:[] as {id:string;listing:Listing|null}[]};}
 const result=await client.from('saved_listings').select('listing_id,created_at').eq('user_id',owner).order('created_at',{ascending:false}).order('listing_id',{ascending:true}).range((page-1)*24,page*24-1);
 if(result.error||!Array.isArray(result.data)||result.data.length>24||result.data.some(row=>!validId(row.listing_id))||new Set(result.data.map(row=>row.listing_id)).size!==result.data.length)throw new Error('Unable to load saved properties');
 const ids=result.data.map(row=>row.listing_id);
 const published=ids.length?await client.from('listings').select(listingProjection).eq('status','published').in('id',ids):{data:[],error:null};
 if(published.error||!Array.isArray(published.data)||published.data.length>ids.length)throw new Error('Unable to load saved properties');
 const rows=published.data.map(publicListing);if(rows.some(row=>!ids.includes(row.id))||new Set(rows.map(row=>row.id)).size!==rows.length)throw new Error('Invalid saved property response');
 await verifiedSaveOwner(client,owner);return {total,pages,page,rows:ids.map(id=>({id,listing:rows.find(row=>row.id===id)||null}))};
}
