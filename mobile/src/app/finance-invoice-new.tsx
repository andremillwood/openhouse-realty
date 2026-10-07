import {useCallback} from 'react';
import {ActivityIndicator,ScrollView,Text,View} from 'react-native';
import {Link} from 'expo-router';
import {useIdentity} from '../components/identity';
import {useLoad} from '../components/use-load';
import {FinanceInvoiceCreate} from '../components/finance-invoice-create';
import {invoiceAccess} from '../lib/invoice-access';
import {supabase} from '../lib/supabase';
import {styles} from '../components/styles';
export default function NewInvoice(){const {user,loading}=useIdentity();if(loading)return <ActivityIndicator accessibilityLabel="Checking account"/>;if(!user)return <Link href="/sign-in">Sign in to submit a vendor invoice →</Link>;return <Editor key={user.id} owner={user.id}/>;}
function Editor({owner}:{owner:string}){const loader=useCallback(()=>{if(!supabase)throw Error();return invoiceAccess(supabase,owner);},[owner]);const result=useLoad(owner,loader);if(result.loading)return <ActivityIndicator accessibilityLabel="Checking invoice membership"/>;if(result.error||!result.data)return <View style={styles.page}><Text accessibilityRole="alert">Verified administrator, manager or finance membership is required to submit an invoice.</Text><Link href="/finance-invoices">Vendor invoice register →</Link></View>;return <ScrollView contentContainerStyle={styles.page} keyboardShouldPersistTaps="handled"><FinanceInvoiceCreate owner={owner}/></ScrollView>;}
