import {useCallback} from 'react';
import {ActivityIndicator,Text,View} from 'react-native';
import {Link} from 'expo-router';
import {useIdentity} from '../components/identity';
import {useLoad} from '../components/use-load';
import {FinanceJournalEditor} from '../components/finance-journal-editor';
import {financeAccess} from '../lib/finance-access';
import {supabase} from '../lib/supabase';
import {styles} from '../components/styles';
export default function NewJournal(){const {user,loading}=useIdentity();if(loading)return <ActivityIndicator accessibilityLabel="Checking account"/>;if(!user)return <Link href="/sign-in">Sign in to review a journal posting →</Link>;return <Editor key={user.id} owner={user.id}/>;}
function Editor({owner}:{owner:string}){const loader=useCallback(()=>{if(!supabase)throw Error();return financeAccess(supabase,owner);},[owner]);const result=useLoad(owner,loader);if(result.loading)return <ActivityIndicator accessibilityLabel="Checking finance membership"/>;if(result.error||!result.data)return <View style={styles.page}><Text accessibilityRole="alert">Verified administrator or finance membership is required to post a journal.</Text><Link href="/finance-accounts">Approved account register →</Link></View>;return <View style={{flex:1}}> <FinanceJournalEditor owner={owner}/></View>;}
