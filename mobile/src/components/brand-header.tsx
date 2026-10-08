import {Image,Pressable,StyleSheet,Text,View} from 'react-native';
import {Link} from 'expo-router';
import {Ionicons} from '@react-native-vector-icons/ionicons';
import {useSafeAreaInsets} from 'react-native-safe-area-context';

/** Separate the wordmark from the page title so neither gets squeezed. */
export function BrandHeader({title,canGoBack,onBack}:{title:string;canGoBack:boolean;onBack:()=>void}){
 const insets=useSafeAreaInsets();
 return <View style={[s.header,{paddingTop:insets.top}]}>
  <View style={s.brandRow}>
   <Link href="/" asChild><Pressable accessibilityRole="button" accessibilityLabel="Open House Realty home" style={s.home}><Image source={require('../../assets/logo-blue.png')} resizeMode="contain" style={s.logo} accessible={false}/></Pressable></Link>
   <Link href="/account" asChild><Pressable accessibilityRole="button" accessibilityLabel="Your account" style={s.account}><Ionicons name="person-outline" size={21} color="#003A8C" accessible={false}/></Pressable></Link>
  </View>
  <View style={s.contextRow}>
   {canGoBack&&<Pressable accessibilityRole="button" accessibilityLabel="Go back" onPress={onBack} style={s.back}><Ionicons name="chevron-back" size={21} color="#003A8C" accessible={false}/></Pressable>}
   <Text accessibilityRole="header" numberOfLines={2} style={s.title}>{title}</Text>
  </View>
 </View>;
}
const s=StyleSheet.create({header:{backgroundColor:'#fff',borderBottomWidth:1,borderBottomColor:'#E7EDF5'},brandRow:{paddingHorizontal:20,minHeight:66,flexDirection:'row',alignItems:'center',justifyContent:'space-between'},home:{minHeight:48,justifyContent:'center'},logo:{width:138,height:62},account:{width:48,height:48,borderRadius:16,backgroundColor:'#F1F5FA',alignItems:'center',justifyContent:'center'},contextRow:{minHeight:48,paddingHorizontal:20,paddingBottom:8,flexDirection:'row',alignItems:'center',gap:6},back:{width:36,minHeight:44,justifyContent:'center'},title:{flex:1,fontFamily:'BrandStrong',fontSize:16,lineHeight:22,color:'#0B2346'}});
