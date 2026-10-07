export function reportPeriod(input:Record<string,string|string[]|undefined>){
 const start=input.start,end=input.end;
 if((start===undefined||start==='')&&(end===undefined||end===''))return null;
 function day(value:unknown){
  if(typeof value!=='string'||!/^\d{4}-\d{2}-\d{2}$/.test(value))throw new Error('Choose both a start and end date.');
  const date=new Date(value+'T00:00:00Z');
  if(!Number.isFinite(date.getTime())||date.toISOString().slice(0,10)!==value)throw new Error('Choose valid calendar dates.');
  return value;
 }
 const from=day(start),through=day(end);if(from>through)throw new Error('The end date must be on or after the start date.');
 return {start:from,end:through,from:from+'T00:00:00-05:00',until:new Date(Date.parse(through+'T00:00:00-05:00')+86400000).toISOString()};
}
