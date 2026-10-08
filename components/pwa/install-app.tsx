'use client';
import {useEffect, useRef, useState} from 'react';
type InstallEvent = Event & {prompt: () => Promise<void>; userChoice: Promise<{outcome: 'accepted' | 'dismissed'}>};
export function InstallApp() {
  const [prompt, setPrompt] = useState<InstallEvent | null>(null);
  const [installed, setInstalled] = useState(false);
  const [busy, setBusy] = useState(false);
  const [message, setMessage] = useState('');
  const installing = useRef(false);
  useEffect(() => {
    const capture = (event: Event) => {event.preventDefault(); setPrompt(event as InstallEvent);};
    const complete = () => {setInstalled(true); setPrompt(null);};
    const standalone = window.matchMedia('(display-mode: standalone)');
    const check = () => setInstalled(standalone.matches || (navigator as Navigator & {standalone?: boolean}).standalone === true);
    check(); standalone.addEventListener('change', check);
    window.addEventListener('beforeinstallprompt', capture); window.addEventListener('appinstalled', complete);
    return () => {standalone.removeEventListener('change', check); window.removeEventListener('beforeinstallprompt', capture); window.removeEventListener('appinstalled', complete);};
  }, []);
  async function install() {
    if (!prompt || installing.current) return;
    installing.current = true;
    setBusy(true); setMessage('');
    try {await prompt.prompt(); const choice = await prompt.userChoice; setMessage(choice.outcome === 'accepted' ? 'Installation requested. Open House will appear on your home screen when your browser completes it.' : 'You can install later from your browser menu.');}
    catch {setMessage('Use your browser menu to add Open House to your home screen.');}
    finally {setPrompt(null); setBusy(false); installing.current = false;}
  }
  return <>{installed ? <p role="status">You’re using the installed web app.</p> : <>{prompt && <button className="primary" disabled={busy} onClick={install}>{busy ? 'Opening installation…' : 'Install Open House'}</button>}<h2>On iPhone or iPad</h2><p>Open this website in Safari, tap Share, then Add to Home Screen. Enable Open as Web App if offered, then tap Add.</p><h2>On Android or desktop</h2><p>Choose Install app or Add to Home Screen in your browser menu. The install button appears here when your browser offers installation.</p></>}<p role="status">{message}</p><p>Listings, maps, account records and submissions require an internet connection. Installation uses the same web account and does not require Expo Go.</p></>;
}
