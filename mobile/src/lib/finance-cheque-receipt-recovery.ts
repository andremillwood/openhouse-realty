import {financeChequeReceipt,type ChequeReceipt} from './finance-cheque-receive';
import type {ChequeRecoveryStore} from './finance-cheque-recovery';
import {validId} from './catalog';
const queues=new Map<string,Promise<unknown>>();
function key(owner:string){if(!validId(owner))throw Error('Verified account reference required.');return `cheque-intake-recovery.v1.${owner}`;}
function decode(raw:string,owner:string):ChequeReceipt{
 const value=JSON.parse(raw);if(!value||value.schema!==1||value.owner!==owner)throw Error('Retained cheque request is invalid.');
 const command=financeChequeReceipt(value.command);if(JSON.stringify(command)!==JSON.stringify(value.command))throw Error('Retained cheque request differs from its approved payload.');return command;
}
function serialized<T>(storageKey:string,work:()=>Promise<T>):Promise<T>{const previous=queues.get(storageKey)??Promise.resolve();const result=previous.catch(()=>{}).then(work);queues.set(storageKey,result);void result.finally(()=>{if(queues.get(storageKey)===result)queues.delete(storageKey);}).catch(()=>{});return result;}
export function readChequeReceiptRecovery(store:ChequeRecoveryStore,owner:string){const storageKey=key(owner);return serialized(storageKey,async()=>{const raw=await store.getItem(storageKey);return raw===null?null:decode(raw,owner);});}
/** Persist before sending; never replace a different unresolved request. */
export function retainChequeReceiptRecovery(store:ChequeRecoveryStore,owner:string,value:ChequeReceipt){const command=financeChequeReceipt(value),storageKey=key(owner);return serialized(storageKey,async()=>{
 const raw=await store.getItem(storageKey);if(raw!==null&&JSON.stringify(decode(raw,owner))!==JSON.stringify(command))throw Error('Resolve the retained cheque request first.');
 await store.setItem(storageKey,JSON.stringify({schema:1,owner,command}));const saved=await store.getItem(storageKey);if(saved===null||JSON.stringify(decode(saved,owner))!==JSON.stringify(command))throw Error('Cheque request persistence could not be verified.');return command;
 });}
/** Clear only after a verified receipt or a definitive pre-submission rejection. */
export function clearChequeReceiptRecovery(store:ChequeRecoveryStore,owner:string,value:ChequeReceipt){const command=financeChequeReceipt(value),storageKey=key(owner);return serialized(storageKey,async()=>{const raw=await store.getItem(storageKey);if(raw===null)return;if(JSON.stringify(decode(raw,owner))!==JSON.stringify(command))throw Error('Cannot discard a different retained cheque request.');await store.removeItem(storageKey);if(await store.getItem(storageKey)!==null)throw Error('Retained cheque request could not be cleared.');});}
