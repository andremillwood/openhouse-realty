import {useCallback} from 'react';
import {ActivityIndicator,Pressable,Text,View} from 'react-native';
import {managerReturnVisitContext} from '../lib/manager-return-visit';
import {supabase} from '../lib/supabase';
import {useLoad} from './use-load';
import {ManagerReturnVisit} from './manager-return-visit';
import {styles} from './styles';
export function ManagerReturnContext({owner,work,offer,report}:{owner:string;work:string;offer:string;report:string}){const loader=useCallback(()=>{if(!supabase)throw Error();return managerReturnVisitContext(supabase,owner,work,offer,report);},[owner,work,offer,report]);const result=useLoad(owner+work+offer+report,loader);if(result.loading)return <ActivityIndicator accessibilityLabel="Checking correction assignment"/>;if(result.error||!result.data)return <View style={styles.card}><Text style={styles.body}>Correction context unavailable.</Text><Pressable accessibilityRole="button" onPress={result.retry}><Text style={styles.link}>Refresh correction details</Text></Pressable></View>;const r=result.data;return <ManagerReturnVisit owner={owner} work={work} offer={offer} id={report} version={r.report.version} offerVersion={r.offer.version} workVersion={r.work.version} state={r.report.state} offerState={r.offer.state} workState={r.work.state} onRefresh={result.retry}/>;}
