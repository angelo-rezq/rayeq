import {z} from 'zod';
import configuredRelease from '../config/app-release.json';

export const appReleaseSchema=z.object({
 latestBuild:z.number().int().min(1).max(2100000000),
 latestVersion:z.string().regex(/^\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?$/).max(100),
 minSupportedBuild:z.number().int().min(1),
 apkUrl:z.string().url().max(2000).refine(value=>{try{const u=new URL(value);return u.protocol==='https:'&&!u.username&&!u.password&&!u.search&&!u.hash&&/^\/download\/[A-Za-z0-9._-]+\.apk$/.test(u.pathname)}catch{return false}}),
 sha256:z.string().regex(/^[a-f0-9]{64}$/),
 releaseNotesAr:z.string().trim().min(1).max(4000),
 releaseNotesEn:z.string().trim().min(1).max(4000).optional()
}).strict().refine(value=>value.minSupportedBuild<=value.latestBuild,{message:'Minimum supported build cannot exceed latest build'});
export const appRelease=appReleaseSchema.parse(configuredRelease);
export function appVersionResponse(){return Response.json({data:appRelease},{headers:{
 'Cache-Control':'no-store, max-age=0',
 'CDN-Cache-Control':'no-store',
 'Surrogate-Control':'no-store',
 'Pragma':'no-cache',
 'Expires':'0'
}});}
