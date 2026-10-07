import {useRef,useState} from 'react';
import {ActivityIndicator,Pressable,Text,View} from 'react-native';
import {Link} from 'expo-router';
import {useIdentity} from '../components/identity';
import {ManagerPropertyPicker} from '../components/manager-property-picker';
import {AdminOwnerAccessRegister} from '../components/admin-owner-access-register';
import {styles} from '../components/styles';
import {validId} from '../lib/catalog';
export default function OwnerAccess(){const {user,loading}=useIdentity();if(loading)return <ActivityIndicator accessibilityLabel="Checking account"/>;if(!user)return <View style={styles.page}><Link href="/sign-in" style={styles.link}>Sign in to manage owner portfolio access →</Link></View>;return <Selection key={user.id} owner={user.id}/>;}
function Selection({owner}:{owner:string}){const [property,setProperty]=useState<string|null>(null),selected=useRef(false);return property?<View style={{flex:1}}><AdminOwnerAccessRegister key={owner+property} owner={owner} property={property}/><Pressable accessibilityRole="button" onPress={()=>{selected.current=false;setProperty(null);}}><Text style={styles.link}>Choose another property →</Text></Pressable></View>:<ManagerPropertyPicker owner={owner} onSelect={location=>{if(selected.current||!validId(location.property)||location.unit!==null)return;selected.current=true;setProperty(location.property);}}/>;}
