import type {ConfigContext,ExpoConfig} from 'expo/config';
export default function appConfig({config}:ConfigContext):ExpoConfig{
 const key=process.env.GOOGLE_MAPS_ANDROID_API_KEY;
 const plugins:NonNullable<ExpoConfig['plugins']>=[...(config.plugins||[])];
 if(!plugins.some(plugin=>plugin==='expo-font'||Array.isArray(plugin)&&plugin[0]==='expo-font'))plugins.push('expo-font');
 if(!plugins.some(plugin=>plugin==='expo-splash-screen'||Array.isArray(plugin)&&plugin[0]==='expo-splash-screen'))plugins.push(['expo-splash-screen',{backgroundColor:'#F8FAFC',image:'./assets/logo-blue.png',imageWidth:260,resizeMode:'contain'}]);
 if(!plugins.some(plugin=>plugin==='@react-native-vector-icons/ionicons'||Array.isArray(plugin)&&plugin[0]==='@react-native-vector-icons/ionicons'))plugins.push('@react-native-vector-icons/ionicons');
 if(key)plugins.push(['react-native-maps',{androidGoogleMapsApiKey:key}]);
 return {...config,name:'Open House Realty',slug:'open-house-realty',plugins};
}
