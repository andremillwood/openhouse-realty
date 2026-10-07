import {useCallback} from 'react';
import {ActivityIndicator,FlatList,Pressable,Text,View} from 'react-native';
import {Link,router,useLocalSearchParams} from 'expo-router';
import {useIdentity} from '../../components/identity';
import {useLoad} from '../../components/use-load';
import {styles} from '../../components/styles';
import {catalogQuery} from '../../lib/catalog';
import {applicationDocuments} from '../../lib/application-documents';
import {DocumentWithdraw} from '../../components/document-withdraw';
import {DocumentRecovery} from '../../components/document-recovery';
import {DocumentUpload} from '../../components/document-upload';
import {DocumentOpen} from '../../components/document-open';
import {supabase} from '../../lib/supabase';
export default function Application(){const params=useLocalSearchParams<Record<string,string|string[]>>();const id=typeof params.id==='string'?params.id:'invalid',page=catalogQuery(params).page;const {user,loading}=useIdentity();if(loading)return <View style={styles.page}><ActivityIndicator accessibilityLabel="Checking account"/></View>;if(!user)return <View style={styles.page}><Link href="/sign-in" style={styles.link}>Sign in to view your application →</Link></View>;return <Detail key={user.id+id+page} owner={user.id} id={id} page={page}/>;}
function Detail({owner,id,page}:{owner:string;id:string;page:number}){
 const loader=useCallback(()=>{if(!supabase)throw new Error('Connection unavailable');return applicationDocuments(supabase,owner,id,page);},[owner,id,page]);const result=useLoad(owner+id+page,loader);
 if(result.loading)return <View style={styles.page}><ActivityIndicator accessibilityLabel="Loading supporting documents"/></View>;
 if(result.error)return <View style={styles.page}><Text accessibilityRole="alert" style={styles.body}>Unable to load supporting documents.</Text><Pressable accessibilityRole="button" onPress={result.retry}><Text style={styles.link}>Try again</Text></Pressable></View>;
 if(!result.data)return <View style={styles.page}><Text style={styles.heading}>Documents unavailable</Text><Link href="/applications" style={styles.link}>Your applications →</Link></View>;
 const data=result.data;
 return <FlatList contentContainerStyle={styles.page} data={data.rows} keyExtractor={e=>e.id} ItemSeparatorComponent={()=><View style={{height:18}}/>} ListHeaderComponent={<View style={{gap:18}}><Text style={styles.title}>Supporting documents.</Text><DocumentUpload owner={owner} application={id} onRefresh={result.retry}/><DocumentRecovery owner={owner} application={id}/><Text style={styles.body}>Files recorded as uploaded for this application. Upload status does not mean the team has approved a document.</Text><Text style={styles.body}>{data.total} documents · Page {data.page} of {data.pages}</Text>{!data.total?<Text style={styles.body}>No uploaded supporting documents are recorded.</Text>:!data.rows.length&&<Text style={styles.body}>Documents changed while loading. Refresh to check current files.</Text>}<Link href={{pathname:'/applications/[id]',params:{id}}} style={styles.link}>Application review →</Link></View>} renderItem={({item})=><View style={styles.card}><Text style={styles.heading}>{item.file_name}</Text><Text style={styles.body}>{item.kind.replaceAll('_',' ')}</Text><Text style={styles.body}>Record created {new Date(item.created_at).toLocaleString('en-JM',{timeZone:'America/Jamaica'})}</Text><Text selectable style={styles.body}>Reference: {item.id}</Text><DocumentOpen key={item.id} owner={owner} application={id} id={item.id}/><DocumentWithdraw key={item.id+'-withdraw'} owner={owner} application={id} id={item.id} onRefresh={result.retry}/></View>} ListFooterComponent={<View style={{gap:18,paddingTop:24}}><Pressable accessibilityRole="button" disabled={data.page===1} onPress={()=>router.setParams({page:String(data.page-1)})}><Text style={styles.link}>← Newer</Text></Pressable><Pressable accessibilityRole="button" disabled={data.page===data.pages} onPress={()=>router.setParams({page:String(data.page+1)})}><Text style={styles.link}>Older →</Text></Pressable><Pressable accessibilityRole="button" onPress={result.retry}><Text style={styles.link}>Refresh documents</Text></Pressable></View>}/>;
}
