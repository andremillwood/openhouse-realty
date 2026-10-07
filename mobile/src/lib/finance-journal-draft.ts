import {jmdMinor} from '../../../lib/finance/money';
import {financeJournalCommand} from './finance-journal-command';
import {validId} from './catalog';
export type Choice=Readonly<{id:string;label:string}>;
export type DraftLine=Readonly<{key:string;account:Choice|null;property:Choice|null;unit:Choice|null;side:'debit'|'credit';amount:string}>;
export type JournalDraft=readonly DraftLine[];
export function draftLine(key:string):DraftLine{if(!validId(key))throw Error('Valid draft line reference required.');return Object.freeze({key,account:null,property:null,unit:null,side:'debit',amount:''});}
function choice(v:Choice|null):Choice|null{if(v===null)return null;if(!validId(v.id)||typeof v.label!=='string'||!v.label.trim()||v.label.length>500)throw Error('Approved selection required.');return Object.freeze({id:v.id,label:v.label});}
export function changeDraftLine(lines:JournalDraft,key:string,change:{account?:Choice|null;property?:Choice|null;unit?:Choice|null;side?:'debit'|'credit';amount?:string}):JournalDraft{
 if(!lines.some(l=>l.key===key)||new Set(lines.map(l=>l.key)).size!==lines.length)throw Error('Current draft line required.');
 return Object.freeze(lines.map(l=>{if(l.key!==key)return l;const account=change.account===undefined?l.account:choice(change.account),property=change.property===undefined?l.property:choice(change.property);let unit=change.property===undefined?l.unit:null;if(change.unit!==undefined){unit=choice(change.unit);if(unit&&!property)throw Error('Select the property first.');}const side=change.side??l.side,amount=change.amount??l.amount;if(!['debit','credit'].includes(side)||typeof amount!=='string'||amount.length>20)throw Error('Check the line amount.');return Object.freeze({key,account,property,unit,side,amount});}));
}
export function addDraftLine(lines:JournalDraft,key:string):JournalDraft{if(lines.length>=200||lines.some(l=>l.key===key))throw Error('Use at most 200 distinct lines.');return Object.freeze([...lines,draftLine(key)]);}
export function removeDraftLine(lines:JournalDraft,key:string):JournalDraft{if(lines.length<=2||!lines.some(l=>l.key===key))throw Error('At least two current lines are required.');return Object.freeze(lines.filter(l=>l.key!==key));}
export function reviewJournalDraft(lines:JournalDraft,memo:string,reason:string,approved:boolean,request:string){
 if(new Set(lines.map(l=>l.key)).size!==lines.length)throw Error('Distinct draft lines required.');
 return financeJournalCommand({request_id:request,currency:'JMD',memo,reason,approved:approved as true,lines:lines.map(l=>{if(!l.account)throw Error('Choose an approved account for every line.');const amount=jmdMinor(l.amount);return {account_id:l.account.id,property_id:l.property?.id??null,unit_id:l.unit?.id??null,debit_minor:l.side==='debit'?amount:0,credit_minor:l.side==='credit'?amount:0};})});
}
