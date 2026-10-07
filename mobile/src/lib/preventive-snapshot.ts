import {validId} from './catalog';
export function preventiveSnapshot(value:unknown,id:string,organization:string){
 if(!value||typeof value!=='object'||Array.isArray(value))throw new Error('Approved scope unavailable.');
 const r=value as Record<string,unknown>,date=r.next_due_on;
 if(r.id!==id||r.organization_id!==organization||!validId(r.property_id)||r.unit_id!==null&&!validId(r.unit_id)||typeof r.title!=='string'||r.title.trim().length<3||r.title.length>160||typeof r.description!=='string'||r.description.trim().length<20||r.description.length>5000||!['low','standard','high','urgent'].includes(String(r.priority))||!['active','paused','retired'].includes(String(r.state))||typeof r.version!=='number'||!Number.isInteger(r.version)||r.version<1||r.version>=2147483647||typeof r.interval_days!=='number'||!Number.isInteger(r.interval_days)||r.interval_days<1||r.interval_days>366||typeof date!=='string'||!/^\d{4}-\d{2}-\d{2}$/.test(date)||!Number.isFinite(Date.parse(date+'T00:00:00Z'))||new Date(date+'T00:00:00Z').toISOString().slice(0,10)!==date)throw new Error('Invalid approved preventive scope.');
 return {title:r.title,description:r.description,priority:r.priority as string,state:r.state as string,version:r.version,interval:r.interval_days,due:date,property:r.property_id as string,unit:r.unit_id as string|null};
}
