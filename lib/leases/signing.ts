import {uuidPattern} from '@/lib/enquiries/validation';

/** Staff intent only. Parties, legal document, provider and tenancy authority are server-derived. */
export type LeaseSigningRequest=Readonly<{
 application_id:string;draft_id:string;draft_version:number;request_id:string;
 approval_reference:string;signing_approved:true;
}>;
export function leaseSigningRequestInput(value:unknown):LeaseSigningRequest{
 if(!value||typeof value!=='object'||Array.isArray(value))throw new Error('Check the lease signing request.');
 const input=value as Record<string,unknown>;
 const allowed=['application_id','draft_id','draft_version','request_id','approval_reference','signing_approved'];
 if(Object.keys(input).some(key=>!allowed.includes(key)))throw new Error('Signing parties, documents and authority must come from approved records.');
 for(const key of ['application_id','draft_id','request_id'])if(typeof input[key]!=='string'||!uuidPattern.test(input[key] as string))throw new Error('Valid application, draft and request references required.');
 if(typeof input.draft_version!=='number'||!Number.isInteger(input.draft_version)||input.draft_version<1||input.draft_version>=2147483647)throw new Error('Use the current approved draft version.');
 if(input.signing_approved!==true||typeof input.approval_reference!=='string'||input.approval_reference.length>500||input.approval_reference.trim().length<5)throw new Error('Record explicit approval to request legal signing.');
 return Object.freeze({application_id:input.application_id as string,draft_id:input.draft_id as string,draft_version:input.draft_version,request_id:input.request_id as string,approval_reference:input.approval_reference.trim(),signing_approved:true});
}

/** Provider availability is explicit; a missing adapter cannot simulate successful execution. */
export class LeaseSigningUnavailable extends Error{
 constructor(){super('Legal signing is awaiting an approved provider and business configuration.');this.name='LeaseSigningUnavailable';}
}
export function requireLeaseSigningProvider<T>(provider:T|null|undefined):T{
 if(provider==null)throw new LeaseSigningUnavailable();return provider;
}
