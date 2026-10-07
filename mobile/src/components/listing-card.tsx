import {Image,Text,View} from 'react-native';
import {Link} from 'expo-router';
import {listingPrice,type Listing} from '../lib/catalog';
import {styles} from './styles';
export function ListingCard({row}:{row:Listing}){return <View style={styles.card}>{row.photo_url&&<Image source={{uri:row.photo_url}} accessibilityLabel={row.title} style={{height:200,width:'100%',borderRadius:12}}/>}<Text style={styles.body}>{row.intent==='rent'?'For rent':'For sale'} · {row.area}</Text><Text style={styles.heading}>{row.title}</Text><Text style={styles.body}>{listingPrice(row)}</Text><Text style={styles.body}>{row.bedrooms} beds · {row.bathrooms} baths · {row.parking_spaces} parking</Text><Link href={{pathname:'/listings/[id]',params:{id:row.id}}} style={styles.link}>View property →</Link></View>;}
