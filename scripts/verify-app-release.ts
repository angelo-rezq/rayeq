import {readFile} from 'node:fs/promises';
import {createHash} from 'node:crypto';
import {resolve,basename,join} from 'node:path';
import {appRelease,appReleaseSchema,appVersionResponse,appDownloadOrigins} from '../lib/app-release';

async function main(){
 const url=new URL(appRelease.apkUrl);
 if(!appDownloadOrigins.has(url.origin))throw Error('APK must be hosted on an allow-listed Rayeq origin');
 const root=url.origin==='https://rayeq-releases.onrender.com'?'release-site':'public';
 const file=resolve(join(root,'download',basename(url.pathname)));
 const bytes=await readFile(file);
 if(bytes.length<1024||bytes.readUInt32LE(0)!==0x04034b50)throw Error('APK is not a ZIP package');
 const actual=createHash('sha256').update(bytes).digest('hex');
 if(actual!==appRelease.sha256)throw Error('Release SHA-256 does not match the APK');
 for(const bad of [{latestBuild:0},{minSupportedBuild:appRelease.latestBuild+1},{sha256:'invalid'},{apkUrl:'http://rayeq.invalid/download/test.apk'},{apkUrl:'https://untrusted.invalid/download/test.apk'},{apkUrl:'https://rayeq-releases.onrender.com:8443/download/test.apk'},{apkUrl:'https://rayeq-platform.onrender.com/other/test.apk'},{extra:'unexpected'},{releaseNotesEn:123},{publishedAt:'invalid'},{publishedAt:'2026-11-22T10:49:01+02:00'},{mandatoryAfter:appRelease.publishedAt}]){
  if(appReleaseSchema.safeParse({...appRelease,...bad}).success)throw Error('Release schema accepted invalid metadata');
 }
 const response=appVersionResponse();const data=await response.json();
 if(response.status!==200||data.data.latestBuild!==appRelease.latestBuild||!response.headers.get('Cache-Control')?.includes('no-store')||Date.parse(data.data.mandatoryAfter)-Date.parse(data.data.publishedAt)!==48*60*60*1000||Math.abs(Date.now()-Date.parse(data.data.serverTime))>5000)throw Error('Version response contract failed');
 console.log(JSON.stringify({releaseVerified:true,latestBuild:appRelease.latestBuild,latestVersion:appRelease.latestVersion,minSupportedBuild:appRelease.minSupportedBuild,apkBytes:bytes.length,sha256:actual,invalidMetadataChecks:12}));
}
main().catch(error=>{console.error(error.message);process.exitCode=1});
