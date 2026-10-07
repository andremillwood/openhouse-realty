import {FinanceChequeOpen} from './finance-cheque-open';
import {useCallback} from 'react';
import {ActivityIndicator,Pressable,Text,View} from 'react-native';
import {financeChequeBankHistory} from '../lib/finance-cheque-bank-history';
import {supabase} from '../lib/supabase';
import {useLoad} from './use-load';
import {styles} from './styles';
export function FinanceChequeBankHistory({owner,id,version,onRefresh}:{owner:string;id:string;version:number;onRefresh:()=>void}){
 const loader=useCallback(()=>{if(!supabase)throw Error();return financeChequeBankHistory(supabase,owner,id);},[owner,id]),result=useLoad(JSON.stringify([owner,id,version]),loader);
 if(result.loading)return <ActivityIndicator accessibilityLabel="Verifying frozen cheque bank evidence"/>;
 if(result.error||!result.data||result.data.cheque.version!==version)return <View style={styles.card}><Text accessibilityRole="alert">Complete bank evidence unavailable or cheque changed. Refresh before interpreting its bank decisions.</Text><Pressable accessibilityRole="button" onPress={onRefresh}><Text style={styles.link}>Refresh cheque evidence</Text></Pressable></View>;
 return <View style={styles.card}><Text style={styles.heading}>Frozen bank decision evidence</Text><Text style={styles.body}>Each recorded bank decision retains its certified source document and bank reference. File certification checks the format; it does not independently verify a bank statement or complete reconciliation.</Text>{!result.data.rows.length&&<Text style={styles.body}>No bank decisions or frozen bank documents are recorded for this receipt.</Text>}{result.data.rows.map(file=><View key={file.event} style={styles.card}><Text style={styles.heading}>{file.kind==='deposit'?'Deposit':file.kind==='clearance'?'Clearance':'Return'} · Revision {file.version}</Text><Text style={styles.body}>{file.name} · {file.mime} · {file.size.toLocaleString()} bytes</Text><Text style={styles.body}>Bank reference: {file.bankReference}</Text><Text selectable style={styles.body}>Document reference: {file.evidence}</Text><FinanceChequeOpen key={JSON.stringify([owner,id,version,file.evidence])} owner={owner} cheque={id} id={file.evidence}/><Text style={styles.body}>Frozen {new Date(file.frozen).toLocaleString('en-JM',{timeZone:'America/Jamaica'})} (Jamaica time)</Text></View>)}<Pressable accessibilityRole="button" onPress={onRefresh}><Text style={styles.link}>Refresh cheque evidence</Text></Pressable></View>;
}
