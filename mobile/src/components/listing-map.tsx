import {useState} from 'react';
import {Text,View} from 'react-native';
import MapView,{Marker} from 'react-native-maps';
import {type Listing,listingPrice} from '../lib/catalog';
import {ListingCard} from './listing-card';
import {styles} from './styles';
export function ListingMap({rows}:{rows:Listing[]}){
 const points=rows.filter(row=>row.approximate_latitude!==null&&row.approximate_longitude!==null);
 const [selected,setSelected]=useState<string|null>(null);
 const current=points.find(row=>row.id===selected);
 if(!points.length)return <Text style={styles.body}>No approved map locations are available on this page. Use the property list for details.</Text>;
 const latitudes=points.map(p=>p.approximate_latitude!),longitudes=points.map(p=>p.approximate_longitude!);
 const minLat=Math.min(...latitudes),maxLat=Math.max(...latitudes),minLng=Math.min(...longitudes),maxLng=Math.max(...longitudes);
 return <View style={{gap:18}}><Text style={styles.body}>Showing {points.length} of {rows.length} properties on this page. Pins show approved approximate areas. The team confirms exact addresses when arranging a visit.</Text><MapView style={{height:360,borderRadius:16}} initialRegion={{latitude:(minLat+maxLat)/2,longitude:(minLng+maxLng)/2,latitudeDelta:Math.min(180,Math.max(0.025,(maxLat-minLat)*1.5)),longitudeDelta:Math.min(360,Math.max(0.025,(maxLng-minLng)*1.5))}} showsUserLocation={false} showsMyLocationButton={false} toolbarEnabled={false}><>{points.map(row=><Marker key={row.id} coordinate={{latitude:row.approximate_latitude!,longitude:row.approximate_longitude!}} title={row.title} description={listingPrice(row)} onPress={()=>setSelected(row.id)} pinColor={selected===row.id?'#1E58B8':'#003A8C'}/>)}</></MapView>{current?<ListingCard row={current}/>:<Text style={styles.body}>Select a property pin to see its details.</Text>}</View>;
}
