import {useCallback} from 'react';
import {ActivityIndicator,FlatList,Image,Pressable,Text,View} from 'react-native';
import {useLoad} from '../components/use-load';
import {styles} from '../components/styles';
import {publishedRealtors} from '../lib/realtors';
import {EnquiryForm} from '../components/enquiry-form';
import {RealtorMatch} from '../components/realtor-match';
import {supabase} from '../lib/supabase';
export default function Realtors(){
 const loader=useCallback(()=>{if(!supabase)throw new Error('Connection unavailable');return publishedRealtors(supabase);},[]);const result=useLoad('published-realtors',loader);
 return <FlatList contentContainerStyle={styles.page} data={result.data||[]} keyExtractor={row=>row.id} ItemSeparatorComponent={()=><View style={{height:18}}/>} ListHeaderComponent={<View style={{gap:18}}><Text style={styles.title}>People first. Property follows.</Text><Text style={styles.body}>Meet your partners in the next chapter.</Text>{result.loading?<ActivityIndicator accessibilityLabel="Loading realtors"/>:result.error?<Text accessibilityRole="alert" style={styles.body}>The realtor directory could not be loaded. Please try again.</Text>:result.data?.length===0?<Text style={styles.body}>Open House is preparing its approved realtor profiles.</Text>:null}{!!result.data?.length&&<RealtorMatch roster={result.data}/>}<Pressable accessibilityRole="button" onPress={result.retry}><Text style={styles.link}>Refresh directory</Text></Pressable></View>} renderItem={({item})=><View style={styles.card}>{item.photo_url&&<Image source={{uri:item.photo_url}} accessibilityLabel={item.display_name} style={{height:200,width:'100%',borderRadius:16}}/>}<Text style={styles.heading}>{item.display_name}</Text><Text style={styles.body}>{item.service_areas.join(' · ')}</Text><Text style={styles.body}>{item.bio}</Text><Text style={styles.body}>Supports: {item.supported_intents.join(', ')}</Text><Text style={styles.body}>Working style: {item.communication_style}, {item.guidance_style}, {item.decision_pace}</Text><EnquiryForm realtorId={item.id}/></View>}/>;
}
