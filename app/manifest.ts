import type {MetadataRoute} from 'next';
export default function manifest(): MetadataRoute.Manifest {
  return {
    id: '/', name: 'Open House Realty', short_name: 'Open House',
    description: 'Property discovery and management for Jamaica.',
    start_url: '/', scope: '/', display: 'standalone',
    background_color: '#f8fafc', theme_color: '#003a8c', lang: 'en',
    icons: [{src: '/brand/app-icon.png', sizes: '1254x1254', type: 'image/png', purpose: 'any'}],
  };
}
