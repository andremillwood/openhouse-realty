const {getDefaultConfig}=require('expo/metro-config');
const path=require('node:path');
const config=getDefaultConfig(__dirname);
// The two apps install independently. Watch only the shared pure discovery, document, lease and staff validation
// helpers; do not add the web app's dependency tree to native resolution.
config.watchFolders=[...config.watchFolders,path.resolve(__dirname,'../lib/discovery'),path.resolve(__dirname,'../lib/documents'),path.resolve(__dirname,'../lib/leases'),path.resolve(__dirname,'../lib/enquiries'),path.resolve(__dirname,'../lib/staff'),path.resolve(__dirname,'../lib/security'),path.resolve(__dirname,'../lib/finance'),path.resolve(__dirname,'../lib/reports'),path.resolve(__dirname,'../lib/owners')];
module.exports=config;
