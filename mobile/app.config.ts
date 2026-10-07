import type {ConfigContext,ExpoConfig} from 'expo/config';
export default function appConfig({config}:ConfigContext):ExpoConfig{
 const key=process.env.GOOGLE_MAPS_ANDROID_API_KEY;
 const plugins:NonNullable<ExpoConfig['plugins']>=[...(config.plugins||[])];
 if(key)plugins.push(['react-native-maps',{androidGoogleMapsApiKey:key}]);
 return {...config,name:'Open House Realty',slug:'open-house-realty',plugins};
}
