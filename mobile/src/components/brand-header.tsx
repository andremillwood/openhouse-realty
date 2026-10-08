import {Image,Pressable,StyleSheet,Text,View} from 'react-native';
import {Link} from 'expo-router';
import {Ionicons} from '@react-native-vector-icons/ionicons';
import {useSafeAreaInsets} from 'react-native-safe-area-context';

/** Separate the wordmark from the page title so neither gets squeezed. */
export function BrandHeader({title,canGoBack,onBack}:{title:string;canGoBack:boolean;onBack:()=>void}){
 const insets=useSafeAreaInsets();
 return <View style={[s.header,{paddingTop:insets.top}]}>
  <View style={s.inner}><View style={s.brandRow}>
   {canGoBack?<Pressable accessibilityRole="button" accessibilityLabel="Go back" onPress={onBack} style={s.back}><Ionicons name="chevron-back" size={22} color="#003A8C" accessible={false}/></Pressable>:<View style={s.back}/>}
   <Link href="/" asChild><Pressable accessibilityRole="button" accessibilityLabel="Open House Realty home" style={s.home}><Image source={require('../../assets/logo-blue.png')} resizeMode="contain" style={s.logo} accessible={false}/></Pressable></Link>
   <Link href="/account" asChild><Pressable accessibilityRole="button" accessibilityLabel="Your account" style={s.account}><Ionicons name="person-outline" size={20} color="#003A8C" accessible={false}/></Pressable></Link>
  </View>
  <View style={s.contextRow}><Text accessibilityRole="header" numberOfLines={2} style={s.title}>{title}</Text></View></View>
 </View>;
}
const s=StyleSheet.create({
 header:{backgroundColor:'#fff',borderBottomWidth:1,borderBottomColor:'#E7EDF5'},
 inner:{width:'100%',maxWidth:760,alignSelf:'center'},
 brandRow:{paddingHorizontal:20,minHeight:72,flexDirection:'row',alignItems:'center',justifyContent:'space-between',gap:12},
 home:{flex:1,minHeight:48,alignItems:'center',justifyContent:'center'},
 logo:{width:'100%',maxWidth:176,height:64},
 account:{width:44,height:44,borderRadius:22,backgroundColor:'#F1F5FA',alignItems:'center',justifyContent:'center',borderWidth:1,borderColor:'#E7EDF5'},
 back:{width:44,minHeight:44,borderRadius:22,alignItems:'center',justifyContent:'center'},
 contextRow:{paddingHorizontal:24,paddingTop:2,paddingBottom:18},
 title:{fontFamily:'BrandHeading',fontSize:26,lineHeight:34,color:'#0B2346'},
});
