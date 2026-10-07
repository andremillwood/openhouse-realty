import {useEffect,useState} from 'react';
export function useLoad<T>(key:string,loader:()=>Promise<T>){
 const [attempt,setAttempt]=useState(0);
 const requestKey=JSON.stringify([key,attempt]);
 const [state,setState]=useState<{key:string;data:T|null;error:string;loading:boolean}>({key:requestKey,data:null,error:'',loading:true});
 useEffect(()=>{let active=true;void Promise.resolve().then(async()=>{if(!active)return;setState({key:requestKey,data:null,error:'',loading:true});try{const data=await loader();if(active)setState({key:requestKey,data,error:'',loading:false});}catch{if(active)setState({key:requestKey,data:null,error:'Unable to load properties. Please try again.',loading:false});}});return()=>{active=false;};},[requestKey,loader]);
 const current=state.key===requestKey?state:{key:requestKey,data:null,error:'',loading:true};
 return {...current,retry:()=>setAttempt(value=>value+1)};
}
