import type {NextConfig} from 'next';
const config:NextConfig={async rewrites(){return [{source:'/mobile-demo',destination:'/mobile-demo/index.html'}]},async headers(){return [{source:'/download/:file*.apk',headers:[{key:'Content-Type',value:'application/vnd.android.package-archive'},{key:'Content-Disposition',value:'attachment'},{key:'Cache-Control',value:'public, max-age=3600, immutable'},{key:'X-Content-Type-Options',value:'nosniff'}]}]}};
export default config;
