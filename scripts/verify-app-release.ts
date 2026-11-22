import {readFile} from 'node:fs/promises';
import {createHash} from 'node:crypto';
import {resolve,basename,join} from 'node:path';
import {appRelease,appReleaseSchema,appVersionResponse} from '../lib/app-release';

async function main(){
 const url=new URL(appRelease.apkUrl);
 const expectedOrigin=new URL(process.env.PUBLIC_ORIGIN||process.env.RENDER_EXTERNAL_URL||'https://rayeq-platform.onrender.com').origin;
 if(url.origin!==expectedOrigin)throw Error('APK must be hosted on the configured Rayeq origin');
 const file=resolve(join('public','download',basename(url.pathname)));
 const bytes=await readFile(file);
 if(bytes.length<1024||bytes.readUInt32LE(0)!==0x04034b50)throw Error('APK is not a ZIP package');
 const actual=createHash('sha256').update(bytes).digest('hex');
 if(actual!==appRelease.sha256)throw Error('Release SHA-256 does not match the APK');
 for(const bad of [{latestBuild:0},{minSupportedBuild:appRelease.latestBuild+1},{sha256:'invalid'},{apkUrl:'http://rayeq.invalid/download/test.apk'},{apkUrl:'https://rayeq-platform.onrender.com/other/test.apk'},{extra:'unexpected'}]){
  if(appReleaseSchema.safeParse({...appRelease,...bad}).success)throw Error('Release schema accepted invalid metadata');
 }
 const response=appVersionResponse();const data=await response.json();
 if(response.status!==200||data.data.latestBuild!==appRelease.latestBuild||!response.headers.get('Cache-Control')?.includes('no-store'))throw Error('Version response contract failed');
 console.log(JSON.stringify({releaseVerified:true,latestBuild:appRelease.latestBuild,latestVersion:appRelease.latestVersion,minSupportedBuild:appRelease.minSupportedBuild,apkBytes:bytes.length,sha256:actual,invalidMetadataChecks:6}));
}
main().catch(error=>{console.error(error.message);process.exitCode=1});
