import {FinanceChequePostReview} from './finance-cheque-post-review';
import {readChequePostRecovery} from '../lib/finance-cheque-post-recovery';
import {chequeDeviceStore} from '../lib/finance-cheque-device-store';
import {formatJmdMinor} from '../lib/finance-statement';
import {useCallback} from 'react';
import {ActivityIndicator,Platform,Pressable,Text,View} from 'react-native';
import {Link} from 'expo-router';
import {financeChequePosting} from '../lib/finance-cheque-posting';
import {supabase} from '../lib/supabase';
import {useLoad} from './use-load';
import {styles} from './styles';
export function FinanceChequeAccounting({owner,id,version,onRefresh}:{owner:string;id:string;version:number;onRefresh:()=>void}){
 const loader=useCallback(async()=>{if(!supabase)throw Error();const recovery=Platform.OS==='web'?null:await readChequePostRecovery(chequeDeviceStore,owner,id);const data=await financeChequePosting(supabase,owner,id);return {...data,recovery};},[owner,id]);
 const result=useLoad(JSON.stringify([owner,id,version]),loader);
 if(result.loading)return <ActivityIndicator accessibilityLabel="Verifying cheque accounting and reversal journals"/>;
 if(result.error||!result.data||result.data.cheque.version!==version)return <View style={styles.card}><Text accessibilityRole="alert" style={styles.body}>Accounting records could not be verified, or the cheque changed. Refresh before making an accounting decision.</Text><Pressable accessibilityRole="button" onPress={onRefresh}><Text style={styles.link}>Refresh cheque and accounting</Text></Pressable></View>;
 const {posting,cheque,recovery}=result.data;
 return <View style={styles.card}><Text style={styles.heading}>Accounting record</Text><Text style={styles.body}>Custody and bank clearance are separate from accounting. A journal does not independently reconcile the bank or allocate a resident payment.</Text>{posting?<><Text style={styles.body}>{posting.reason}</Text><Text style={styles.body}>Posted {new Date(posting.posted).toLocaleString('en-JM',{timeZone:'America/Jamaica'})} (Jamaica time)</Text><Link href={{pathname:'/finance-journal',params:{id:posting.journal}}} style={styles.link}>Open cleared-cheque journal →</Link>{posting.reversal&&<><Text style={styles.body}>Reversal verified: {posting.reversal.reason}</Text><Link href={{pathname:'/finance-journal',params:{id:posting.reversal.reversal}}} style={styles.link}>Open reversal journal →</Link></>}</>:<Text style={styles.body}>{cheque.state==='cleared'?'This cleared cheque has no accounting posting. A separate approved posting is required.':'No cleared-cheque accounting posting recorded.'}</Text>}{Platform.OS!=='web'&&(recovery||!posting&&cheque.state==='cleared')&&<FinanceChequePostReview key={JSON.stringify([owner,id,version])} owner={owner} id={id} version={version} amount={formatJmdMinor(cheque.amount)} recovery={recovery} onRefresh={onRefresh}/>}</View>;
}
