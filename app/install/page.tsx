import {SiteHeader} from '@/components/discovery/site-header';
import {InstallApp} from '@/components/pwa/install-app';
export const metadata = {title: 'Install Open House | Open House Realty'};
export default function InstallPage() {
  return <><SiteHeader/><main className="account-layout"><section className="account-card"><img src="/brand/app-icon.png" width="88" height="88" alt="" className="install-icon"/><p className="eyebrow">Open House on your phone</p><h1>Your property journey, close at hand.</h1><p>Add Open House to your home screen for a dedicated web app experience.</p><InstallApp/><a href="/">Explore Open House →</a></section></main></>;
}
