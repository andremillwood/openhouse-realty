export type Home = { id: string; title: string; area: string; intent: 'rent' | 'sale'; price: number; beds: number; baths: number; parking: number; size: number; lat: number; lng: number; photo: string; description: string };
export const homes: Home[] = [
  {id:'residence-8c',title:'Residence 8C',area:'Kingston 6',intent:'rent',price:295000,beds:2,baths:2,parking:1,size:1310,lat:18.026,lng:-76.775,photo:'photo-1600596542815-ffad4c1539a9',description:'An airy apartment concept with a balcony, modern interiors, and space to make your own. Explore the neighborhood and discuss your priorities with the Open House team.'},
  {id:'residence-6a',title:'Residence 6A',area:'Kingston 6',intent:'rent',price:285000,beds:2,baths:2.5,parking:2,size:1420,lat:18.019,lng:-76.784,photo:'photo-1600607687920-4e2a09cf159d',description:'A spacious apartment concept for a connected city lifestyle. Two parking spaces and a flexible layout make this a useful starting point for your property search.'},
  {id:'norbrook-12',title:'Norbrook Residence',area:'Norbrook',intent:'rent',price:315000,beds:2,baths:2,parking:2,size:1480,lat:18.066,lng:-76.786,photo:'photo-1600047509807-ba8f99d2cdde',description:'A furnished residence concept with a balcony and generous living spaces. Start with the area, then let your realtor help you explore the details that matter.'},
  {id:'kingston-family',title:'Garden House',area:'Kingston 6',intent:'sale',price:48500000,beds:4,baths:4,parking:2,size:3200,lat:18.032,lng:-76.766,photo:'photo-1613977257363-707ba9348227',description:'A family home concept with indoor-outdoor living and room for a new chapter. This sample illustrates the buying journey; pricing and imagery are demonstration content.'}
];
export const photoUrl=(home:Home)=>`https://images.unsplash.com/${home.photo}?auto=format&fit=crop&w=1200&q=85`;
export const priceLabel=(home:Home)=>`JMD ${home.price.toLocaleString('en-JM')}${home.intent==='rent'?' / month':''}`;
export type MatchPreferences = { communication: string; guidance: string; pace: string; area: string; intent: string };
export type Realtor = {id:string;name:string;initials:string;tagline:string;bio:string;areas:string[];intents:string[];communication:string;guidance:string;pace:string};
export const realtors:Realtor[]=[
 {id:'sample-avery',name:'Avery · sample profile',initials:'A',tagline:'A calm guide for your next chapter',bio:'A sample of a realtor who explains each step, listens closely, and gives you space to weigh your options.',areas:['Kingston 6','Norbrook'],intents:['buy','rent'],communication:'thoughtful',guidance:'step-by-step',pace:'considered'},
 {id:'sample-jordan',name:'Jordan · sample profile',initials:'J',tagline:'Clear answers. Confident decisions.',bio:'A sample of a realtor who leads with comparisons, direct answers, and a focused plan for your property search.',areas:['Kingston 6'],intents:['buy','sell'],communication:'direct',guidance:'data-led',pace:'decisive'},
 {id:'sample-morgan',name:'Morgan · sample profile',initials:'M',tagline:'A collaborative partner in your search',bio:'A sample of a realtor who explores possibilities with you, offers a flexible shortlist, and adapts to your schedule.',areas:['Norbrook','Kingston 6'],intents:['rent','buy','sell'],communication:'collaborative',guidance:'independent',pace:'flexible'}
];
export function matchRealtors(preferences:MatchPreferences){
 const labels:Record<string,string>={communication:'communication style',guidance:'guidance preference',pace:'decision pace'};
 return realtors.filter(realtor=>realtor.areas.includes(preferences.area) && realtor.intents.includes(preferences.intent)).map(realtor=>{
  const reasons:string[]=[];let points=0;
  for(const key of ['communication','guidance','pace'] as const)if(realtor[key]===preferences[key]){points+=2;reasons.push(`Matches your ${labels[key]}`);}
  if(realtor.areas.includes(preferences.area)){points+=1;reasons.push(`Serves ${preferences.area}`);}
  if(realtor.intents.includes(preferences.intent)){points+=1;reasons.push(`Supports your ${preferences.intent} journey`);}
  return {realtor,points,reasons};
 }).sort((a,b)=>b.points-a.points||a.realtor.name.localeCompare(b.realtor.name));
}
