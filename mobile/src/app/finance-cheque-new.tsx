import {useCallback} from 'react';
import {ActivityIndicator,Platform,Pressable,ScrollView,Text,View} from 'react-native';
import {Link} from 'expo-router';
import {useIdentity} from '../components/identity';
import {useLoad} from '../components/use-load';
import {FinanceChequeCreate} from '../components/finance-cheque-create';
import {financeAccess} from '../lib/finance-access';
import {readChequeReceiptRecovery} from '../lib/finance-cheque-receipt-recovery';
import {chequeDeviceStore} from '../lib/finance-cheque-device-store';
import {supabase} from '../lib/supabase';
import {styles} from '../components/styles';
export default function NewCheque(){const {user,loading}=useIdentity();if(loading)return <ActivityIndicator accessibilityLabel="Checking account"/>;if(!user)return <Link href="/sign-in">Sign in to record a cheque receipt →</Link>;if(Platform.OS==='web')return <View style={styles.page}><Text style={styles.body}>Use the installed app to record cheque receipts with encrypted recovery.</Text><Link href="/finance-cheques" style={styles.link}>Cheque register →</Link></View>;return <Editor key={user.id} owner={user.id}/>;}
function Editor({owner}:{owner:string}){const loader=useCallback(async()=>{if(!supabase)throw Error();const access=await financeAccess(supabase,owner);if(!access)throw Error();const recovery=await readChequeReceiptRecovery(chequeDeviceStore,owner);const current=await financeAccess(supabase,owner);if(!current||current.organization!==access.organization||current.role!==access.role||current.revision!==access.revision)throw Error();return {recovery};},[owner]);const result=useLoad(owner,loader);if(result.loading)return <ActivityIndicator accessibilityLabel="Checking finance access and retained receipt request"/>;if(result.error||!result.data)return <View style={styles.page}><Text accessibilityRole="alert">Finance access or encrypted request recovery could not be verified. Recover the retained request before creating another receipt.</Text><Pressable accessibilityRole="button" onPress={result.retry}><Text style={styles.link}>Retry access and recovery check</Text></Pressable><Link href="/finance-cheques" style={styles.link}>Cheque register →</Link></View>;return <ScrollView keyboardShouldPersistTaps="handled" contentContainerStyle={styles.page}><FinanceChequeCreate owner={owner} recovery={result.data.recovery}/></ScrollView>;}
