import type {ChequeState} from './finance-cheques';
import type {ChequeCommand} from './finance-cheque-command';

/** Custody choices only. A clearance decision does not post an accounting journal. */
export function financeChequeDecisions(state:ChequeState):readonly {
 action:ChequeCommand['action'];label:string;kind:'deposit'|'clearance'|'return'|null;
}[] {
 switch(state){
  case 'received':return [{action:'cancel',label:'Cancel receipt',kind:null},{action:'record_deposit',label:'Record deposit',kind:'deposit'}];
  case 'deposited':return [{action:'confirm_clear',label:'Record bank clearance',kind:'clearance'},{action:'record_return',label:'Record bank return',kind:'return'}];
  case 'cleared':return [{action:'record_return',label:'Record bank return',kind:'return'}];
  case 'returned':case 'cancelled':return [];
  default:throw Error('Unrecognized cheque custody state.');
 }
}
