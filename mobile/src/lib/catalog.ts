import type {SupabaseClient} from '@supabase/supabase-js';
import {catalogQuery,CATALOG_PAGE_SIZE} from '../../../lib/discovery/catalog-query';
export {catalogQuery};
export type Filters=ReturnType<typeof catalogQuery>;
export const listingProjection='id,title,area,intent,property_type,price_jmd,bedrooms,bathrooms,parking_spaces,size_sq_ft,description,photo_url,approximate_latitude,approximate_longitude,location_label';
export const validId=(value:unknown):value is string=>typeof value==='string'&&/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(value);
export type Listing={id:string;title:string;area:string;intent:'rent'|'sale';property_type:string;price_jmd:string;bedrooms:number;bathrooms:number;parking_spaces:number;size_sq_ft:number|null;description:string|null;photo_url:string|null;approximate_latitude:number|null;approximate_longitude:number|null;location_label:string|null};
export function publicListing(raw:unknown):Listing{
 if(!raw||typeof raw!=='object')throw new Error('Invalid property response.');const r=raw as Record<string,unknown>;
 const text=(key:string,nullable=false)=>{const value=r[key];if(nullable&&value===null)return null;if(typeof value!=='string'||(!nullable&&!value.trim()))throw new Error('Invalid property response.');return value;};
 const number=(key:string)=>{const value=r[key];if(typeof value!=='number'||!Number.isFinite(value)||value<0)throw new Error('Invalid property response.');return value;};
 if(!validId(r.id)||!['sale','rent'].includes(String(r.intent))||!['apartment','townhouse','house','land','commercial'].includes(String(r.property_type)))throw new Error('Invalid property response.');
 const price=String(r.price_jmd);if(!/^\d{1,12}(\.\d{1,2})?$/.test(price)||Number(price)<=0)throw new Error('Invalid property response.');
 const lat=r.approximate_latitude,lng=r.approximate_longitude;
 if(!((lat===null&&lng===null)||(typeof lat==='number'&&Number.isFinite(lat)&&Math.abs(lat)<=90&&typeof lng==='number'&&Number.isFinite(lng)&&Math.abs(lng)<=180)))throw new Error('Invalid property response.');
 const size=r.size_sq_ft===null?null:number('size_sq_ft');
 const photo=text('photo_url',true);let safePhoto:string|null=null;if(photo){try{const url=new URL(photo);if(url.protocol==='https:'&&!url.username&&!url.password)safePhoto=url.toString();}catch{}}
 return {id:r.id,title:text('title')!,area:text('area')!,intent:r.intent as Listing['intent'],property_type:String(r.property_type),price_jmd:price,bedrooms:number('bedrooms'),bathrooms:number('bathrooms'),parking_spaces:number('parking_spaces'),size_sq_ft:size,description:text('description',true),photo_url:safePhoto,approximate_latitude:lat as number|null,approximate_longitude:lng as number|null,location_label:text('location_label',true)};
}
export function listingPrice(row:Listing){const [whole,decimal]=row.price_jmd.split('.');return `JMD ${BigInt(whole).toLocaleString('en-JM')}${decimal&&Number(decimal)?'.'+decimal.padEnd(2,'0'):''}${row.intent==='rent'?' / month':''}`;}
export function areaMapLink(row:Listing){return row.approximate_latitude===null||row.approximate_longitude===null?null:`https://www.google.com/maps/search/?api=1&query=${row.approximate_latitude},${row.approximate_longitude}`;}
export async function loadCatalog(client:SupabaseClient,filters:Filters){
 const query=(head:boolean)=>{let q=client.from('listings').select(head?'id':listingProjection,{count:'exact',head}).eq('status','published');if(filters.intent!=='all')q=q.eq('intent',filters.intent);if(filters.area)q=q.ilike('area',`%${filters.area}%`);if(filters.q)q=q.or(`title.ilike.%${filters.q}%,area.ilike.%${filters.q}%`);return q;};
 const countResult=await query(true);if(countResult.error||!Number.isSafeInteger(countResult.count)||countResult.count!<0)throw new Error('Properties are temporarily unavailable.');
 const total=countResult.count!,pages=Math.max(1,Math.ceil(total/CATALOG_PAGE_SIZE)),page=Math.min(filters.page,pages);
 if(!total)return {rows:[] as Listing[],total,pages,page};
 const result=await query(false).order('published_at',{ascending:false}).order('id',{ascending:true}).range((page-1)*CATALOG_PAGE_SIZE,page*CATALOG_PAGE_SIZE-1);
 if(result.error||!Array.isArray(result.data)||result.data.length>CATALOG_PAGE_SIZE)throw new Error('Properties are temporarily unavailable.');
 return {rows:result.data.map(publicListing),total,pages,page};
}
export async function loadListing(client:SupabaseClient,id:unknown){
 if(!validId(id))return null;
 const result=await client.from('listings').select(listingProjection).eq('status','published').eq('id',id).maybeSingle();
 if(result.error)throw new Error('This property is temporarily unavailable.');return result.data?publicListing(result.data):null;
}
