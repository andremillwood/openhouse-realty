import {uuidPattern} from '@/lib/enquiries/validation';
/** Only known journeys can be resumed after sign-in. */
export function authReturnPath(value:unknown):string{
 if(typeof value!=='string')return '/account';
 if(value==='/workspace'||value==='/sell'||value==='/realtors'||value==='/realtors#match')return value;
 const match=/^\/listings\/([^/#?]+)(#(?:enquiry|viewing))?$/.exec(value);
 return match&&uuidPattern.test(match[1])?value:'/account';
}
export function propertySignInHref(listingId:string,section?:'enquiry'|'viewing'){
 return `/sign-in?next=${encodeURIComponent(authReturnPath(`/listings/${listingId}${section?`#${section}`:''}`))}`;
}
