import {financeChequeCommand,type ChequeCommand} from './finance-cheque-command';
import {validId} from './catalog';
export type ChequeRecoveryStore={getItem:(key:string)=>Promise<string|null>;setItem:(key:string,value:string)=>Promise<void>;removeItem:(key:string)=>Promise<void>};
const queues=new Map<string,Promise<unknown>>();
function key(owner:string,cheque:string){if(!validId(owner)||!validId(cheque))throw Error('Verified account and cheque references required.');return `cheque-recovery.v1.${owner}.${cheque}`;}
function decode(raw:string,owner:string,cheque:string):ChequeCommand{
 const value=JSON.parse(raw);if(!value||value.schema!==1||value.owner!==owner||value.cheque!==cheque)throw Error('Retained cheque request is invalid.');
 const command=financeChequeCommand(value.command);if(command.cheque_id!==cheque||JSON.stringify(command)!==JSON.stringify(value.command))throw Error('Retained cheque request differs from its approved payload.');return command;
}
function serialized<T>(storageKey:string,work:()=>Promise<T>):Promise<T>{const previous=queues.get(storageKey)??Promise.resolve();const result=previous.catch(()=>{}).then(work);queues.set(storageKey,result);void result.finally(()=>{if(queues.get(storageKey)===result)queues.delete(storageKey);}).catch(()=>{});return result;}
export function readChequeRecovery(store:ChequeRecoveryStore,owner:string,cheque:string){const storageKey=key(owner,cheque);return serialized(storageKey,async()=>{const raw=await store.getItem(storageKey);return raw===null?null:decode(raw,owner,cheque);});}
/** Persist before sending; never replace a different unresolved request. */
export function retainChequeRecovery(store:ChequeRecoveryStore,owner:string,value:ChequeCommand){const command=financeChequeCommand(value),storageKey=key(owner,command.cheque_id);return serialized(storageKey,async()=>{
 const raw=await store.getItem(storageKey);if(raw!==null&&JSON.stringify(decode(raw,owner,command.cheque_id))!==JSON.stringify(command))throw Error('Resolve the retained cheque request first.');
 await store.setItem(storageKey,JSON.stringify({schema:1,owner,cheque:command.cheque_id,command}));const saved=await store.getItem(storageKey);if(saved===null||JSON.stringify(decode(saved,owner,command.cheque_id))!==JSON.stringify(command))throw Error('Cheque request persistence could not be verified.');return command;
 });}
/** Clear only after a verified receipt or a definitive pre-submission rejection. */
export function clearChequeRecovery(store:ChequeRecoveryStore,owner:string,value:ChequeCommand){const command=financeChequeCommand(value),storageKey=key(owner,command.cheque_id);return serialized(storageKey,async()=>{const raw=await store.getItem(storageKey);if(raw===null)return;if(JSON.stringify(decode(raw,owner,command.cheque_id))!==JSON.stringify(command))throw Error('Cannot discard a different retained cheque request.');await store.removeItem(storageKey);if(await store.getItem(storageKey)!==null)throw Error('Retained cheque request could not be cleared.');});}
