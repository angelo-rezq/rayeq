import type {NextConfig} from 'next';
const config:NextConfig={async headers(){return [{source:'/download/:file*.apk',headers:[{key:'Content-Type',value:'application/vnd.android.package-archive'},{key:'Content-Disposition',value:'attachment; filename="rayeq-pilot-arm64-1.0.0.apk"'},{key:'Cache-Control',value:'public, max-age=3600, immutable'},{key:'X-Content-Type-Options',value:'nosniff'}]}]}};
export default config;
