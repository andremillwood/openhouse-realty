'use client';
import {useEffect,useRef,useState} from 'react';
import type {Home} from '@/lib/discovery/data';
import {priceLabel} from '@/lib/discovery/data';
import 'leaflet/dist/leaflet.css';
export function PropertyMap({homes,selected,onSelect,demo=true}:{homes:Home[];selected?:string;onSelect?:(id:string)=>void;demo?:boolean}){
 const container=useRef<HTMLDivElement>(null);const liveMap=useRef<import('leaflet').Map|null>(null),markers=useRef(new Map<string,import('leaflet').Marker>()),selectedRef=useRef(selected),locationRequest=useRef(0),locationBusy=useRef(false);selectedRef.current=selected;const [locationStatus,setLocationStatus]=useState(''),[locating,setLocating]=useState(false);const [failed,setFailed]=useState(false),[mapReady,setMapReady]=useState(false);const selectRef=useRef(onSelect);selectRef.current=onSelect;
 useEffect(()=>{let disposed=false;let map:import('leaflet').Map|undefined;let observer:ResizeObserver|undefined;setMapReady(false);setFailed(false);locationBusy.current=false;setLocating(false);setLocationStatus('');
 import('leaflet').then(L=>{if(disposed||!container.current)return;
 map=L.map(container.current,{scrollWheelZoom:false}).setView([18.04,-76.78],12);liveMap.current=map;
 const tiles=L.tileLayer('https://tile.openstreetmap.org/{z}/{x}/{y}.png',{maxZoom:18,attribution:'&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors'}).addTo(map);
 tiles.on('tileerror',()=>{if(!disposed)setFailed(true)});
 homes.forEach(home=>{const marker=L.marker([home.lat,home.lng],{title:`${home.title}, ${priceLabel(home)}`,icon:L.divIcon({className:'price-marker',html:`<span class="${home.id===selectedRef.current?'selected':''}">${home.intent==='rent'?Math.round(home.price/1000)+'K':(home.price/1000000).toFixed(1)+'M'}</span>`,iconSize:[70,34],iconAnchor:[35,17]})}).addTo(map!);markers.current.set(home.id,marker);marker.on('click',()=>selectRef.current?.(home.id));});
 if(homes.length)map.fitBounds(L.latLngBounds(homes.map(h=>[h.lat,h.lng] as [number,number])),{padding:[60,60],maxZoom:14});
 if(typeof ResizeObserver!=='undefined'){observer=new ResizeObserver(()=>map?.invalidateSize());observer.observe(container.current);}
 map.on('unload',()=>observer?.disconnect());setMapReady(true);
 }).catch(()=>{if(!disposed){locationRequest.current++;locationBusy.current=false;liveMap.current=null;markers.current.clear();observer?.disconnect();map?.remove();map=undefined;setMapReady(false);setLocating(false);setFailed(true);}});
 return()=>{disposed=true;locationRequest.current++;locationBusy.current=false;liveMap.current=null;markers.current.clear();observer?.disconnect();map?.remove();map=undefined};
 },[homes]);
 useEffect(()=>{markers.current.forEach((marker,id)=>marker.getElement()?.querySelector('span')?.classList.toggle('selected',id===selected));},[selected]);
 function locate(){
  if(!liveMap.current||locationBusy.current)return;
  if(!navigator.geolocation){setLocationStatus('Device location is unavailable. Choose an area or browse the list.');return;}
  const request=++locationRequest.current;locationBusy.current=true;setLocating(true);setLocationStatus('Waiting for device location…');
  try{navigator.geolocation.getCurrentPosition(position=>{if(request!==locationRequest.current||!liveMap.current)return;locationBusy.current=false;setLocating(false);const {latitude,longitude}=position.coords;if(!Number.isFinite(latitude)||!Number.isFinite(longitude)||Math.abs(latitude)>90||Math.abs(longitude)>180){setLocationStatus('Device location could not be used. Choose an area or browse the list.');return;}liveMap.current.setView([latitude,longitude],14);setLocationStatus('Map centered near your device. Property pins show approximate locations.');},error=>{if(request!==locationRequest.current||!liveMap.current)return;locationBusy.current=false;setLocating(false);setLocationStatus(error.code===1?'Location access was declined. Choose an area or browse the list.':'Device location is unavailable. Choose an area or browse the list.');},{enableHighAccuracy:false,timeout:10000,maximumAge:60000});}catch{locationBusy.current=false;setLocating(false);setLocationStatus('Device location is unavailable. Choose an area or browse the list.');}
 }

 return <div className="map-shell"><button type="button" className="secondary map-location-button" disabled={locating||!mapReady} onClick={locate}>{locating?'Finding location…':'Use my location'}</button><p className="map-location-status" role="status" aria-live="polite">{locationStatus}</p><div ref={container} className="property-map" role="region" aria-label={demo?"Interactive map of approximate demo property locations":"Interactive map of approved approximate property locations"} />{failed&&<p className="map-warning" role="status">Map tiles are unavailable. You can still browse every home in the list.</p>}<p className="map-note">{demo?'Approximate demo locations':'Approved approximate locations'} · exact addresses confirmed by your realtor. Device location is not saved to your account.</p></div>
}
