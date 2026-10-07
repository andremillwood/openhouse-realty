import {useRef,useState} from 'react';
import {ActivityIndicator,ScrollView,Pressable,Text,View} from 'react-native';
import {Link} from 'expo-router';
import {useIdentity} from '../components/identity';
import {ManagerPropertyPicker} from '../components/manager-property-picker';
import {ManagerInventoryRegister} from '../components/manager-inventory-register';
import {ManagerInventoryEditor} from '../components/manager-inventory-editor';
import {styles} from '../components/styles';
import {validId} from '../lib/catalog';
export default function ManagedInventory(){const {user,loading}=useIdentity();if(loading)return <ActivityIndicator accessibilityLabel="Checking account"/>;if(!user)return <View style={styles.page}><Link href="/sign-in" style={styles.link}>Sign in to inspect private inventory →</Link></View>;return <Selection key={user.id} owner={user.id}/>;}
function Selection({owner}:{owner:string}){const [property,setProperty]=useState<string|null>(null),selected=useRef(false),[creating,setCreating]=useState(false);if(creating)return <ScrollView contentContainerStyle={styles.page}><ManagerInventoryEditor owner={owner} action="property_create" property={null} target={null} version={0} initial={{name:"",area:"",address_text:""}} onRefresh={()=>{selected.current=false;setCreating(false);}}/></ScrollView>;return property?<View style={{flex:1}}><ManagerInventoryRegister key={owner+property} owner={owner} property={property}/><Pressable accessibilityRole="button" onPress={()=>{selected.current=false;setProperty(null);}}><Text style={styles.link}>Choose another property →</Text></Pressable></View>:<View style={{flex:1}}><Pressable accessibilityRole="button" onPress={()=>{if(selected.current)return;selected.current=true;setCreating(true);}}><Text style={styles.link}>Create private managed property →</Text></Pressable><ManagerPropertyPicker owner={owner} onSelect={location=>{if(selected.current||!validId(location.property)||location.unit!==null)return;selected.current=true;setProperty(location.property);}}/></View>;}
