import assert from 'node:assert/strict';
import sharp from 'sharp';
import {writeFile} from 'node:fs/promises';
const urls=[
 'https://rayeq-platform.onrender.com/api/v1/barber-portraits/ee062ce8-cac2-491e-8cf3-2077f3be3815?v=4',
 'https://rayeq-platform.onrender.com/api/v1/work-photos/d0e00000-0000-4000-8000-000000000601'
];
async function main(){const results:any[]=[];for(const url of urls)for(const method of ['GET','HEAD','OPTIONS']){
 const response=await fetch(url,{method,redirect:'error',headers:{Origin:'https://preview.example.test'}});
 assert.equal(response.status,method==='OPTIONS'?204:200);assert.equal(response.headers.get('access-control-allow-origin'),'*');assert.equal(response.headers.get('cross-origin-resource-policy'),'cross-origin');assert.equal(response.headers.get('cache-control'),'no-store');assert.equal(response.headers.get('x-content-type-options'),'nosniff');
 const bytes=Buffer.from(await response.arrayBuffer());let image;
 if(method==='GET'){assert.equal(response.headers.get('content-type'),'image/webp');const meta=await sharp(bytes).metadata();assert.ok(meta.width&&meta.height);image={width:meta.width,height:meta.height,format:meta.format,bytes:bytes.length,hasExif:!!meta.exif};}
 if(method==='HEAD'){assert.equal(response.headers.get('content-type'),'image/webp');assert.equal(bytes.length,0);}
 results.push({url:response.url,method,status:response.status,contentType:response.headers.get('content-type'),cors:response.headers.get('access-control-allow-origin'),cache:response.headers.get('cache-control'),bytes:bytes.length,image});
 }
 const privateResponse=await fetch('https://rayeq-platform.onrender.com/api/v1/profile/avatar',{headers:{Origin:'https://preview.example.test'}});assert.equal(privateResponse.status,401);assert.equal(privateResponse.headers.get('access-control-allow-origin'),null);
 const result={checkedAt:new Date().toISOString(),publicMedia:results,privateAvatar:{status:privateResponse.status,publicCors:false}};
 await writeFile('/tmp/rayeq-public-media-http-live.json',JSON.stringify(result,null,2));console.log(JSON.stringify(result,null,2));
}
main().catch(error=>{console.error('PUBLIC MEDIA HTTP',error.message);process.exitCode=1});
