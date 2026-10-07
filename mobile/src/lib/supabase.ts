import 'react-native-url-polyfill/auto';
import {Platform} from 'react-native';
import {createClient} from '@supabase/supabase-js';
import * as SecureStore from 'expo-secure-store';
const url=process.env.EXPO_PUBLIC_SUPABASE_URL;
const key=process.env.EXPO_PUBLIC_SUPABASE_PUBLISHABLE_KEY;
// Supabase sessions stay in native encrypted storage. Storage failures propagate;
// never fall back to an unencrypted cache or pretend persistence succeeded.
const storage={
 getItem:(name:string)=>SecureStore.getItemAsync(name),
 setItem:(name:string,value:string)=>SecureStore.setItemAsync(name,value),
 removeItem:(name:string)=>SecureStore.deleteItemAsync(name)
};
export const supabase=url&&/^https:\/\/[a-z0-9-]+\.supabase\.co$/.test(url)&&key?.startsWith('sb_publishable_')
 ?createClient(url,key,{auth:{...(Platform.OS!=='web'?{storage}:{}),flowType:'pkce',autoRefreshToken:true,persistSession:Platform.OS!=='web',detectSessionInUrl:false}}):null;
