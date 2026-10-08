import {useEffect,useRef,useState} from 'react';
import {Platform,Pressable,Text,TextInput,View} from 'react-native';
import {Link} from 'expo-router';
import {randomUUID} from 'expo-crypto';
import {jmdMinor} from '../../../lib/finance/money';
import {financeChequeReceipt,receiveFinanceCheque,type ChequeReceipt} from '../lib/finance-cheque-receive';
import {retainChequeReceiptRecovery,clearChequeReceiptRecovery} from '../lib/finance-cheque-receipt-recovery';
import {chequeDeviceStore} from '../lib/finance-cheque-device-store';
import {formatJmdMinor} from '../lib/finance-statement';
import {FinanceDimensionPicker} from './finance-dimension-picker';
import {EnquiryFailure} from '../lib/enquiries';
import {supabase} from '../lib/supabase';
import {styles} from './styles';
export function FinanceChequeCreate({owner,recovery}:{owner:string;recovery:ChequeReceipt|null}){
 const [payer,setPayer]=useState(''),[bank,setBank]=useState(''),[number,setNumber]=useState(''),[amount,setAmount]=useState(''),[reason,setReason]=useState('');
 const [property,setProperty]=useState<{id:string;label:string}|null>(null),[picker,setPicker]=useState(false),[approved,setApproved]=useState(false);
 const [review,setReview]=useState<ChequeReceipt|null>(recovery),[busy,setBusy]=useState(false),[uncertain,setUncertain]=useState(!!recovery),[receipt,setReceipt]=useState<Awaited<ReturnType<typeof receiveFinanceCheque>>|null>(null),[message,setMessage]=useState('');
 const mounted=useRef(true),active=useRef(false),locked=useRef(!!recovery),complete=useRef(false),frozen=useRef<ChequeReceipt|null>(recovery),unknown=useRef(!!recovery);
 useEffect(()=>{mounted.current=true;return()=>{mounted.current=false;};},[]);
 const editable=()=>mounted.current&&!locked.current&&!active.current&&!complete.current&&!frozen.current;
 function change(set:(v:string)=>void,v:string){if(editable()){set(v);setApproved(false);}}
 function prepare(){if(!editable()||!approved||picker)return;try{if(!property)throw Error();const input=financeChequeReceipt({request_id:randomUUID(),action:'receive',cheque_id:null,version:0,property_id:property.id,payer_name:payer,bank_name:bank,cheque_reference:number,amount_minor:jmdMinor(amount),reason,approved:true});locked.current=true;setReview(input);setMessage('');}catch{setMessage('Choose a property and check the payer, bank, cheque reference, positive JMD amount and reason. Confirm your approval before review.');}}
 async function submit(){if(Platform.OS==='web'||!mounted.current||active.current||complete.current||!review||!supabase)return;active.current=true;setBusy(true);try{const input=frozen.current??review;frozen.current=input;await retainChequeReceiptRecovery(chequeDeviceStore,owner,input);if(!mounted.current)return;const result=await receiveFinanceCheque(supabase,owner,input);await clearChequeReceiptRecovery(chequeDeviceStore,owner,input);if(mounted.current){complete.current=true;setReceipt(result);setUncertain(false);setMessage('Receipt verified against its retained custody record and audit.');}}catch(error){if(mounted.current){const pending=unknown.current||!(error instanceof EnquiryFailure)||error.uncertain;unknown.current=pending;if(!pending){try{await clearChequeReceiptRecovery(chequeDeviceStore,owner,frozen.current??review);frozen.current=null;}catch{unknown.current=true;setUncertain(true);setMessage('Retained request could not be cleared. Retry this same receipt request.');return;}}setUncertain(pending);setMessage(pending?'Receipt could not be confirmed. Retry this same request before recording another cheque.':'Receipt was not confirmed. Check the details and current finance authority.');}}finally{active.current=false;if(mounted.current)setBusy(false);}}
 if(Platform.OS==='web')return <Text style={styles.body}>Use the installed app to record a receipt with encrypted request recovery.</Text>;
 return <View style={styles.card}><Text style={styles.heading}>Record a cheque receipt</Text><Text style={styles.body}>Record the cheque you have received. This records custody; deposit, bank clearance and ledger posting are separate steps. Approved requests are saved in encrypted device storage before submission.</Text>
 {!receipt&&!review&&<>
  <Text style={styles.body}>Payer</Text><TextInput accessibilityLabel="Payer name" maxLength={160} value={payer} onChangeText={v=>change(setPayer,v)} style={styles.input}/>
  <Text style={styles.body}>Bank</Text><TextInput accessibilityLabel="Bank name" maxLength={160} value={bank} onChangeText={v=>change(setBank,v)} style={styles.input}/>
  <Text style={styles.body}>Cheque reference</Text><TextInput accessibilityLabel="Cheque reference" maxLength={80} value={number} onChangeText={v=>change(setNumber,v)} style={styles.input}/>
  <Text style={styles.body}>Amount in JMD</Text><TextInput accessibilityLabel="Cheque amount in JMD" keyboardType="decimal-pad" maxLength={20} value={amount} onChangeText={v=>change(setAmount,v)} style={styles.input}/>
  <Text style={styles.body}>Property: {property?.label??'Choose the property for this cheque'}</Text><Pressable accessibilityRole="button" onPress={()=>{if(editable())setPicker(true);}}><Text style={styles.link}>Choose property</Text></Pressable>
  {picker&&<><FinanceDimensionPicker owner={owner} kind="property" property={null} onSelect={choice=>{if(editable()&&picker){setProperty(choice);setPicker(false);setApproved(false);}}}/><Pressable accessibilityRole="button" onPress={()=>{if(editable())setPicker(false);}}><Text style={styles.link}>Cancel selection</Text></Pressable></>}
  <Text style={styles.body}>Receipt reason</Text><TextInput accessibilityLabel="Cheque receipt reason" multiline maxLength={500} value={reason} onChangeText={v=>change(setReason,v)} style={styles.input}/>
  <Pressable accessibilityRole="checkbox" accessibilityState={{checked:approved}} onPress={()=>{if(editable())setApproved(!approved);}}><Text style={styles.body}>{approved?'☑':'☐'} I confirm these cheque details for receipt.</Text></Pressable>
  <Pressable accessibilityRole="button" disabled={picker} onPress={prepare}><Text style={styles.link}>Review cheque receipt</Text></Pressable>
 </>}
 {!receipt&&review&&<><Text style={styles.heading}>{review.payer_name}</Text><Text style={styles.body}>{review.bank_name} · Cheque {review.cheque_reference}</Text><Text style={styles.body}>{formatJmdMinor(String(review.amount_minor))}</Text><Text style={styles.body}>Property: {property?.label??review.property_id}</Text><Text style={styles.body}>Reason: {review.reason}</Text><Text selectable style={styles.body}>Request: {review.request_id}</Text><Pressable accessibilityRole="button" disabled={busy} onPress={()=>void submit()}><Text style={styles.link}>{busy?'Recording receipt…':uncertain?'Retry same cheque receipt':'Confirm cheque receipt'}</Text></Pressable>{!busy&&!uncertain&&<Pressable accessibilityRole="button" onPress={()=>{if(mounted.current&&!active.current&&!complete.current&&!frozen.current){locked.current=false;setReview(null);setApproved(false);}}}><Text style={styles.link}>Edit receipt</Text></Pressable>}</>}
 {!!message&&<Text accessibilityLiveRegion="polite" style={styles.body}>{message}</Text>}
 {receipt&&<><Text style={styles.body}>Current state: {receipt.currentState} · Revision {receipt.currentVersion}</Text><Link href={{pathname:'/finance-cheque',params:{id:receipt.id}}} style={styles.link}>Open custody history and bank documents →</Link></>}
 </View>;
}
