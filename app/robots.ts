import type {MetadataRoute} from 'next';
export default function robots():MetadataRoute.Robots{
 return {rules:{userAgent:'*',allow:'/',disallow:['/account','/workspace','/staff','/security','/applications','/apply','/cosigners','/auth','/api','/sign-in','/demo']},sitemap:'https://www.openhousejamaica.com/sitemap.xml'};
}
