import {useState} from 'react';
import {Link,router} from 'expo-router';
import {Pressable,Text,TextInput,View} from 'react-native';
import {invitationReference} from '../../lib/cosigners';
import {styles} from '../../components/styles';
export default function Invitations(){const [reference,setReference]=useState(''),[error,setError]=useState('');function open(){try{const id=invitationReference(reference);setError('');router.push({pathname:'/cosigners/[id]',params:{id}});}catch{setError('Paste the invitation link or its full reference.');}}
 return <View style={styles.page}><Text style={styles.title}>Co-signer invitations.</Text><Text style={styles.body}>Paste the private invitation link from your email, or its reference. Sign in with the verified email that received it. Only an invited recipient can review or consent.</Text><TextInput accessibilityLabel="Invitation link or reference" autoCapitalize="none" autoCorrect={false} value={reference} onChangeText={setReference} style={styles.input}/><Pressable accessibilityRole="button" onPress={open} style={styles.button}><Text style={styles.buttonText}>Open invitation</Text></Pressable>{!!error&&<Text accessibilityRole="alert" style={styles.body}>{error}</Text>}<Link href="/" style={styles.link}>Home →</Link></View>;
}
