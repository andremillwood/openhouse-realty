import {Text,View} from 'react-native';
import {Link} from 'expo-router';
import {areaMapLink,type Listing} from '../lib/catalog';
import {styles} from './styles';
export function ListingMap({rows}:{rows:Listing[]}){const points=rows.filter(row=>areaMapLink(row));return <View style={{gap:18}}><Text style={styles.body}>Explore approved approximate areas. Exact addresses are confirmed by the team when arranging a visit.</Text>{points.length?points.map(row=><Link key={row.id} href={areaMapLink(row)!} style={styles.link}>{row.title} · {row.area} ↗</Link>):<Text style={styles.body}>No approved map locations are available on this page.</Text>}</View>;}
