import {useCallback} from 'react';
import {ActivityIndicator,Pressable,Text,View} from 'react-native';
import {Link} from 'expo-router';
import {financeInvoicePosting} from '../lib/finance-invoice-posting';
import {formatJmdMinor} from '../lib/finance-statement';
import {supabase} from '../lib/supabase';
import {FinanceInvoicePostReview} from './finance-invoice-post-review';
import {useLoad} from './use-load';
import {styles} from './styles';
export function FinanceInvoiceLedger({owner,id,version,onRefresh}:{owner:string;id:string;version:number;onRefresh:()=>void}){
 const loader=useCallback(()=>{if(!supabase)throw Error();return financeInvoicePosting(supabase,owner,id);},[owner,id]),result=useLoad(JSON.stringify([owner,id,version]),loader);
 if(result.loading)return <ActivityIndicator accessibilityLabel="Verifying invoice ledger posting"/>;
 if(result.error||!result.data||result.data.invoice.version!==version)return <View style={styles.card}><Text accessibilityRole="alert">Invoice posting unavailable or invoice changed. Refresh before posting.</Text><Pressable accessibilityRole="button" onPress={onRefresh}><Text style={styles.link}>Refresh invoice</Text></Pressable></View>;
 const {invoice,posting:p}=result.data;
 if(!p)return invoice.state==='approved'?<FinanceInvoicePostReview key={JSON.stringify([owner,id,version])} owner={owner} id={id} version={version} amount={formatJmdMinor(invoice.amount)} onRefresh={onRefresh}/>:<Text style={styles.body}>Ledger posting requires an independently approved invoice and its reviewed source.</Text>;
 return <View style={styles.card}><Text style={styles.heading}>Retained invoice posting</Text><Text style={styles.body}>{p.reason}</Text><Text style={styles.body}>Posted by {p.actor} · {new Date(p.posted).toLocaleString('en-JM',{timeZone:'America/Jamaica'})} (Jamaica time)</Text><Link href={{pathname:'/finance-journal',params:{id:p.journal}}} style={styles.link}>View original posted journal →</Link>{p.reversal?<><Text style={styles.body}>Posting reversed: {p.reversal.reason}. The original posting remains retained. This invoice cannot be posted again.</Text><Link href={{pathname:'/finance-journal',params:{id:p.reversal.reversal}}} style={styles.link}>View reversal journal →</Link></>:<Text style={styles.body}>Ledger posting does not confirm vendor payment.</Text>}<Pressable accessibilityRole="button" onPress={onRefresh}><Text style={styles.link}>Refresh invoice posting</Text></Pressable></View>;
}
