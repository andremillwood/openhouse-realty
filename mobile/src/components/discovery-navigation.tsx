import {Link,usePathname} from 'expo-router';
import {Ionicons} from '@react-native-vector-icons/ionicons';
import {Pressable,Text,View,StyleSheet} from 'react-native';
import {useSafeAreaInsets} from 'react-native-safe-area-context';
const items=[
 {href:'/',label:'Home',icon:'home-outline',activeIcon:'home'},
 {href:'/listings',label:'Search',icon:'search-outline',activeIcon:'search'},
 {href:'/saved',label:'Saved',icon:'heart-outline',activeIcon:'heart'},
 {href:'/enquiries',label:'Enquiries',icon:'chatbubble-ellipses-outline',activeIcon:'chatbubble-ellipses'},
 {href:'/account',label:'Account',icon:'person-circle-outline',activeIcon:'person-circle'}
] as const;
function selectedDestination(path:string){
 if(path==='/')return '/';
 if(path.startsWith('/listings')||['/demo-listings','/demo-property','/realtors','/demo-realtors'].includes(path))return '/listings';
 if(path==='/saved'||path==='/demo-saved')return '/saved';
 if(path==='/enquiries')return '/enquiries';
 return '/account';
}
export function DiscoveryNavigation(){
 const path=usePathname(),insets=useSafeAreaInsets();
 if(path.startsWith('/auth/')||path==='/sign-in'||path==='/register')return null;
 const active=selectedDestination(path);
 return <View accessibilityRole="tablist" style={[s.bar,{paddingBottom:Math.max(insets.bottom,10)}]}>{items.map(item=>{
  const selected=active===item.href;
  return <Link asChild key={item.href} href={item.href}><Pressable accessibilityRole="tab" accessibilityLabel={item.label} accessibilityState={{selected}} style={s.item}>
   <View style={[s.iconWrap,selected&&s.selected]}><Ionicons name={selected?item.activeIcon:item.icon} size={23} color={selected?'#003A8C':'#718096'} accessible={false}/></View>
   <Text style={[s.label,selected&&s.active]}>{item.label}</Text>
  </Pressable></Link>;
 })}</View>;
}
const s=StyleSheet.create({bar:{flexDirection:'row',backgroundColor:'#fff',borderTopWidth:1,borderColor:'#E2E8F0',paddingTop:6},item:{flex:1,alignItems:'center',justifyContent:'center',minHeight:54,gap:3},iconWrap:{width:48,height:30,borderRadius:12,alignItems:'center',justifyContent:'center'},selected:{backgroundColor:'#EAF1FA'},label:{fontFamily:'BrandStrong',fontSize:10,color:'#52647B'},active:{color:'#003A8C'}});
