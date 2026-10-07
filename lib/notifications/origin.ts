/** Email links always use an explicit HTTPS site origin, never an incoming Host. */
export function notificationOrigin(value:unknown):string|null{
 if(typeof value!=='string'||value.length>300)return null;
 try{const url=new URL(value);if(url.protocol!=='https:'||url.username||url.password||url.pathname!=='/'||url.search||url.hash||!url.hostname.includes('.')||url.hostname==='localhost'||url.hostname.endsWith('.localhost')||/^(?:\d{1,3}\.){3}\d{1,3}$/.test(url.hostname))return null;return url.origin;}catch{return null;}
}
