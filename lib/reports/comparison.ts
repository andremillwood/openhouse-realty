import {reportPeriod} from './period';
export function comparisonPeriod(input:Record<string,string|string[]|undefined>){
 const current=reportPeriod(input);
 if(!current)throw new Error('Choose both dates to compare periods.');
 const start=Date.parse(current.from),until=Date.parse(current.until);
 const days=(until-start)/86400000;
 const previousStart=new Date(start-days*86400000-5*3600000).toISOString().slice(0,10);
 const previousEnd=new Date(start-86400000-5*3600000).toISOString().slice(0,10);
 if(!/^\d{4}-/.test(previousStart)||previousStart<'0001-01-01')throw new Error('Choose a later start date for the preceding period.');
 const previous=reportPeriod({start:previousStart,end:previousEnd})!;
 return {current,previous,days};
}
export function countDelta(current:number|null,previous:number|null){
 if(current===null||previous===null)return 'Unavailable';
 const difference=BigInt(current)-BigInt(previous);
 return `${difference>0n?'+':''}${difference.toLocaleString('en-JM')}`;
}
