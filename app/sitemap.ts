import type {MetadataRoute} from 'next';
export default function sitemap():MetadataRoute.Sitemap{
 return ['','/about','/services','/contact','/listings','/realtors','/sell','/open-houses'].map(path=>({url:`https://www.openhousejamaica.com${path}`}));
}
