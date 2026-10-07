import {useCallback,useRef,useState} from 'react';
import {ActivityIndicator,Image,Pressable,ScrollView,Text,View} from 'react-native';
import {useLocalSearchParams} from 'expo-router';
import * as Linking from 'expo-linking';
import {areaMapLink,listingPrice,loadListing} from '../../lib/catalog';
import {supabase} from '../../lib/supabase';
import {useLoad} from '../../components/use-load';
import {ListingMap} from '../../components/listing-map';
import {styles} from '../../components/styles';
import {SaveProperty} from '../../components/save-property';
import {EnquiryForm} from '../../components/enquiry-form';
import {ApplicationForm} from '../../components/application-form';
import {ViewingForm} from '../../components/viewing-form';
export default function Property(){
 const {id}=useLocalSearchParams<{id:string|string[]}>();const key=typeof id==='string'?id:'invalid';
 const loader=useCallback(()=>{if(!supabase)throw new Error('Connection unavailable');return loadListing(supabase,id);},[id]);
 const result=useLoad(key,loader);const [message,setMessage]=useState('');const opening=useRef(false);
 async function explore(){const url=result.data&&areaMapLink(result.data);if(!url||opening.current)return;opening.current=true;setMessage('');try{await Linking.openURL(url);}catch{setMessage('Unable to open the map. Please try again.');}finally{opening.current=false;}}
 if(result.loading)return <View style={styles.page}><ActivityIndicator color="#003A8C" accessibilityLabel="Loading property"/></View>;
 if(result.error)return <View style={styles.page}><Text accessibilityRole="alert" style={styles.body}>{result.error}</Text><Pressable accessibilityRole="button" onPress={result.retry}><Text style={styles.link}>Try again</Text></Pressable></View>;
 if(!result.data)return <View style={styles.page}><Text style={styles.heading}>Property unavailable</Text><Text style={styles.body}>This property is no longer published or the link is invalid.</Text></View>;
 const row=result.data;
 return <ScrollView contentContainerStyle={styles.page}><Text style={styles.body}>{row.intent==='rent'?'For rent':'For sale'} · {row.area}</Text><Text style={styles.title}>{row.title}</Text><Text style={styles.heading}>{listingPrice(row)}</Text><SaveProperty listingId={row.id}/>{row.photo_url&&<Image source={{uri:row.photo_url}} style={{height:280,width:'100%',borderRadius:16}} accessibilityLabel={row.title}/>}<Text style={styles.body}>{row.bedrooms} bedrooms · {row.bathrooms} bathrooms · {row.parking_spaces} parking spaces{row.size_sq_ft?` · ${row.size_sq_ft.toLocaleString('en-JM')} sq ft`:''}</Text><Text style={styles.heading}>Space for your next chapter.</Text><Text style={styles.body}>{row.description||'Ask the team for more information about this property.'}</Text><EnquiryForm key={row.id} listingId={row.id}/><ViewingForm key={row.id} listingId={row.id}/>{row.intent==='rent'&&<ApplicationForm key={row.id} listingId={row.id}/>}<Text style={styles.heading}>Get to know the area.</Text>{areaMapLink(row)?<><ListingMap key={row.id} rows={[row]}/><Pressable accessibilityRole="button" onPress={()=>void explore()} style={styles.button}><Text style={styles.buttonText}>Explore approximate area ↗</Text></Pressable></>:<Text style={styles.body}>The team can confirm location details when arranging your visit.</Text>}{!!message&&<Text accessibilityRole="alert" style={styles.body}>{message}</Text>}<Pressable accessibilityRole="button" onPress={result.retry}><Text style={styles.link}>Refresh property details</Text></Pressable></ScrollView>;
}
