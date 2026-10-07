'use client';
export default function ErrorPage({ retry }: { error:Error & {digest?:string};retry:()=>void }) {
  return <main className="account-layout"><section className="account-card"><h1>Let’s try that again.</h1><p>We couldn’t load this page. Your saved records remain in your account.</p><button className="primary" onClick={retry}>Try again</button><p><a href="/">Return home</a></p></section></main>;
}
