'use client';
import {useEffect, useState} from 'react';
export function WebApp() {
  const [offline, setOffline] = useState(false);
  useEffect(() => {
    const update = () => setOffline(!navigator.onLine);
    update(); window.addEventListener('online', update); window.addEventListener('offline', update);
    if (process.env.NODE_ENV === 'production' && 'serviceWorker' in navigator) {
      void navigator.serviceWorker.register('/sw.js', {scope: '/', updateViaCache: 'none'}).catch(() => {});
    }
    return () => {window.removeEventListener('online', update); window.removeEventListener('offline', update);};
  }, []);
  return offline ? <div className="connection-banner" role="status">You’re offline. Reconnect before submitting or changing records. Check your account after reconnecting if a previous submission was interrupted.</div> : null;
}
