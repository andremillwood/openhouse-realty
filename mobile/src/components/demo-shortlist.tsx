import {createContext,useContext,useState,type ReactNode} from 'react';
import {Pressable,Text} from 'react-native';
import {homes} from '../../../lib/discovery/data';
import {styles} from './styles';
type Shortlist={ids:readonly string[];toggle:(id:string)=>void;clear:()=>void};
const Context=createContext<Shortlist|null>(null);
export function DemoShortlistProvider({children}:{children:ReactNode}){const [ids,setIds]=useState<string[]>([]);function toggle(id:string){if(!homes.some(home=>home.id===id))return;setIds(current=>current.includes(id)?current.filter(value=>value!==id):[...current,id]);}return <Context.Provider value={{ids,toggle,clear:()=>setIds([])}}>{children}</Context.Provider>}
export function useDemoShortlist(){const value=useContext(Context);if(!value)throw Error('Demo shortlist provider required.');return value;}
export function DemoSave({id}:{id:string}){const {ids,toggle}=useDemoShortlist();const saved=ids.includes(id);return <Pressable accessibilityRole="button" accessibilityLabel={saved?'Remove from demo shortlist':'Save to demo shortlist'} accessibilityState={{selected:saved}} onPress={()=>toggle(id)}><Text style={styles.link}>{saved?'♥ Saved to demo shortlist':'♡ Save demo property'}</Text></Pressable>}
