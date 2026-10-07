import {useCallback} from 'react';
import {ActivityIndicator,ScrollView,Text,View} from 'react-native';
import {Link,router} from 'expo-router';
import {useIdentity} from '../components/identity';
import {useLoad} from '../components/use-load';
import {FinanceAccountReview} from '../components/finance-account-review';
import {financeAccess} from '../lib/finance-access';
import {supabase} from '../lib/supabase';
import {styles} from '../components/styles';
export default function NewAccount(){const {user,loading}=useIdentity();if(loading)return <ActivityIndicator accessibilityLabel="Checking account"/>;if(!user)return <Link href="/sign-in">Sign in to register an approved account →</Link>;return <Editor key={user.id} owner={user.id}/>;}
function Editor({owner}:{owner:string}){const loader=useCallback(()=>{if(!supabase)throw Error();return financeAccess(supabase,owner);},[owner]);const result=useLoad(owner,loader);if(result.loading)return <ActivityIndicator accessibilityLabel="Checking administrator membership"/>;if(result.error||result.data?.role!=='admin')return <View style={styles.page}><Text accessibilityRole="alert">Verified administrator membership is required to register an account.</Text><Link href="/finance-accounts">Approved account register →</Link></View>;return <ScrollView contentContainerStyle={styles.page} keyboardShouldPersistTaps="handled"><FinanceAccountReview owner={owner} onRefresh={()=>router.replace('/finance-accounts')}/></ScrollView>;}
