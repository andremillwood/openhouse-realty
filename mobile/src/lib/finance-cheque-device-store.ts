import {Platform} from 'react-native';
import * as SecureStore from 'expo-secure-store';
import type {ChequeRecoveryStore} from './finance-cheque-recovery';
function native(){if(Platform.OS==='web')throw Error('Use the installed mobile app for encrypted cheque recovery.');}
export const chequeDeviceStore:ChequeRecoveryStore={
 getItem:async key=>{native();return SecureStore.getItemAsync(key);},
 setItem:async(key,value)=>{native();await SecureStore.setItemAsync(key,value);},
 removeItem:async key=>{native();await SecureStore.deleteItemAsync(key);}
};
