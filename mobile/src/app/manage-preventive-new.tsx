import {useRef,useState} from 'react';
import {ActivityIndicator,Pressable,ScrollView,Text,View} from 'react-native';
import {Link} from 'expo-router';
import {useIdentity} from '../components/identity';
import {ManagerPropertyPicker} from '../components/manager-property-picker';
import {ManagerUnitPicker} from '../components/manager-unit-picker';
import {ManagerPreventiveCreate} from '../components/manager-preventive-create';
import {styles} from '../components/styles';
import type {managerLocation} from '../lib/manager-locations';
import {validId} from '../lib/catalog';
type Location=Awaited<ReturnType<typeof managerLocation>>;
export default function NewPlan(){const {user,loading}=useIdentity();if(loading)return <ActivityIndicator accessibilityLabel="Checking account"/>;if(!user)return <View style={styles.page}><Link href="/sign-in" style={styles.link}>Sign in to create a preventive plan →</Link></View>;return <Journey key={user.id} owner={user.id}/>;}
function Journey({owner}:{owner:string}){const [property,setProperty]=useState<Location|null>(null),[location,setLocation]=useState<Location|null>(null),phase=useRef<'property'|'unit'|'form'>('property');
 if(location)return <ScrollView contentContainerStyle={styles.page}><Text style={styles.title}>Approve a preventive plan.</Text><ManagerPreventiveCreate key={owner+location.property+(location.unit||'whole')} owner={owner} location={location}/><Text style={styles.body}>If a response is uncertain, retry the same request here and check plan history before starting another creation.</Text><Link href="/manage-preventive-plans" style={styles.link}>Plan register →</Link></ScrollView>;
 if(property)return <View style={{flex:1}}><ManagerUnitPicker key={owner+property.property} owner={owner} property={property.property} onSelect={selected=>{if(phase.current!=='unit'||selected.property!==property.property||selected.unit!==null&&!validId(selected.unit))return;phase.current='form';setLocation(selected);}}/><Pressable accessibilityRole="button" onPress={()=>{if(phase.current!=='unit')return;phase.current='property';setProperty(null);}}><Text style={styles.link}>Choose a different property →</Text></Pressable></View>;
 return <ManagerPropertyPicker owner={owner} onSelect={selected=>{if(phase.current!=='property'||!validId(selected.property)||selected.unit!==null)return;phase.current='unit';setProperty(selected);}}/>;
}
