import {SiteHeader} from '@/components/discovery/site-header';
import {ListingBrowser} from '@/components/discovery/listing-browser';
export default async function ListingsPage({searchParams}:{searchParams:Promise<{intent?:string}>}){const {intent}=await searchParams;return <><SiteHeader/><main><ListingBrowser initialIntent={intent==='sale'||intent==='rent'?intent:'all'}/></main></>}
