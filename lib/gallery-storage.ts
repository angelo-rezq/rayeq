import sharp from 'sharp';import {randomUUID} from 'node:crypto';
import {pool,DB,tx,audit} from './db';import {fail} from './auth';
export const galleryLimits={maxPhotos:6,maxInputBytes:5*1024*1024,maxPixels:16_000_000,maxEdge:1600,maxOutputBytes:250*1024,maxStorageBytes:60*1024*1024};
const origin=()=>String(process.env.PUBLIC_ORIGIN||process.env.RENDER_EXTERNAL_URL||'').replace(/\/$/,'');
export function photoDTO(r:any){return{id:r.id,url:origin()+'/api/v1/work-photos/'+r.id,width:r.width,height:r.height,byteSize:r.byte_size,createdAt:r.created_at,demoOnly:Boolean(r.demo_seed)}}
export async function galleryFor(db:DB,employeeId:string,demoSeed?:string,all=false){const rows=(await db.query('SELECT id,width,height,byte_size,created_at,demo_seed FROM rayeq_work_photos WHERE employee_id=$1 AND ($3::boolean OR demo_seed IS NULL OR demo_seed=$2) ORDER BY created_at DESC,id DESC',[employeeId,demoSeed||null,all])).rows;return{items:rows.map(photoDTO),maxPhotos:galleryLimits.maxPhotos}}
let encoding=false;
export async function encodeWorkPhoto(input:Buffer,mime:string){
 const formats:Record<string,string>={'image/jpeg':'jpeg','image/png':'png','image/webp':'webp'};
 if(!formats[mime])fail(415,'UNSUPPORTED_IMAGE_TYPE','اختر صورة JPEG أو PNG أو WebP');if(input.byteLength>galleryLimits.maxInputBytes)fail(413,'IMAGE_TOO_LARGE','الحد الأقصى للصورة 5 ميجابايت');
 const magic=mime==='image/jpeg'?input.subarray(0,3).equals(Buffer.from([255,216,255])):mime==='image/png'?input.subarray(0,8).equals(Buffer.from([137,80,78,71,13,10,26,10])):input.subarray(0,4).toString()==='RIFF'&&input.subarray(8,12).toString()==='WEBP';
 if(!magic)fail(400,'INVALID_IMAGE','نوع الصورة لا يطابق محتواها');if(encoding)fail(429,'IMAGE_PROCESSOR_BUSY','حاول رفع الصورة بعد لحظات');encoding=true;
 try{
  const options={limitInputPixels:galleryLimits.maxPixels,failOn:'warning' as const},meta=await sharp(input,options).metadata();if(meta.format!==formats[mime]||(meta.pages||1)>1||!meta.width||!meta.height||meta.width*meta.height>galleryLimits.maxPixels)throw Error('Invalid static image');
  for(const[edge,quality]of[[1600,82],[1600,65],[1280,65],[1024,60],[800,55],[640,50]]){const output=await sharp(input,options).rotate().resize(edge,edge,{fit:'inside',withoutEnlargement:true}).webp({quality,effort:4}).toBuffer({resolveWithObject:true});if(output.data.byteLength<=galleryLimits.maxOutputBytes)return{bytes:output.data,width:output.info.width,height:output.info.height};}
  throw Error('Image budget exceeded');
 }catch{fail(400,'INVALID_IMAGE','اختر صورة ثابتة سليمة لا تتجاوز 16 ميجابكسل')}finally{encoding=false}
}
export async function readWorkPhoto(req:Request){
 const mime=(req.headers.get('content-type')||'').split(';')[0].toLowerCase();if(!['image/jpeg','image/png','image/webp'].includes(mime))fail(415,'UNSUPPORTED_IMAGE_TYPE','اختر صورة JPEG أو PNG أو WebP');
 if(Number(req.headers.get('content-length')||0)>galleryLimits.maxInputBytes)fail(413,'IMAGE_TOO_LARGE','الحد الأقصى للصورة 5 ميجابايت');
 const reader=req.body?.getReader();if(!reader)fail(400,'INVALID_IMAGE','أضف صورة صحيحة');const chunks:Uint8Array[]=[];let size=0;while(true){const part=await reader.read();if(part.done)break;size+=part.value.byteLength;if(size>galleryLimits.maxInputBytes){await reader.cancel();fail(413,'IMAGE_TOO_LARGE','الحد الأقصى للصورة 5 ميجابايت')}chunks.push(part.value)}return encodeWorkPhoto(Buffer.concat(chunks),mime);
}
export async function employeeDemoSeed(db:DB,employeeId:string){const manifests=(await db.query("SELECT value FROM rayeq_settings WHERE key LIKE 'demo:%'")).rows;return manifests.find(r=>r.value.employeeId===employeeId||(r.value.nearbyVirtualEmployeeIds||[]).includes(employeeId))?.value.seedId as string|undefined}
export async function storeWorkPhoto(actorId:string,employeeId:string,photo:{bytes:Buffer,width:number,height:number},demoSeed?:string,workerId?:string,id:string=randomUUID()){
 return tx(async db=>{
  let manifest:any;if(demoSeed){manifest=(await db.query('SELECT value FROM rayeq_settings WHERE key=$1 FOR SHARE',['demo:'+demoSeed])).rows[0]?.value;const c=(await db.query("SELECT value FROM rayeq_settings WHERE key='config' FOR SHARE")).rows[0]?.value;if(!manifest||manifest.seedId!==demoSeed||!c?.isDemo||!c.demoPilot?.enabled||c.demoPilot.seedId!==demoSeed||!(Date.parse(c.demoPilot.expiresAt)>Date.now())||![manifest.employeeId,...(manifest.nearbyVirtualEmployeeIds||[])].includes(employeeId))fail(409,'DEMO_EXPIRED','التجربة غير متاحة حالياً');}
  await db.query("SELECT pg_advisory_xact_lock(hashtextextended('rayeq-gallery-storage',0))");const e=(await db.query('SELECT e.*,u.role FROM rayeq_employees e LEFT JOIN rayeq_users u ON u.id=e.user_id WHERE e.id=$1 FOR UPDATE OF e',[employeeId])).rows[0];
  if(!e?.active||(workerId&&e.user_id!==workerId)||(!demoSeed&&e.role!=='worker'))fail(403,'WORKER_NOT_ACTIVE','حساب العامل غير مفعّل');if(manifest&&(e.id===manifest.employeeId?e.user_id!==manifest.workerUserId:e.user_id!==null))fail(409,'DEMO_IDENTITY_CHANGED','راجع حساب التجربة مع الإدارة');
  const count=(await db.query('SELECT count(*)::int count FROM rayeq_work_photos WHERE employee_id=$1',[employeeId])).rows[0].count;if(count>=galleryLimits.maxPhotos)fail(409,'GALLERY_FULL','وصلت للحد الأقصى: 6 صور. احذف صورة أولاً');const used=Number((await db.query('SELECT COALESCE(sum(byte_size),0)::bigint bytes FROM rayeq_work_photos')).rows[0].bytes);if(used+photo.bytes.byteLength>galleryLimits.maxStorageBytes)fail(507,'GALLERY_STORAGE_FULL','مساحة صور الأعمال ممتلئة، تواصل مع الإدارة');
  const r=(await db.query('INSERT INTO rayeq_work_photos(id,employee_id,image_bytes,byte_size,width,height,demo_seed) VALUES($1,$2,$3,$4,$5,$6,$7) RETURNING id,width,height,byte_size,created_at,demo_seed',[id,employeeId,photo.bytes,photo.bytes.byteLength,photo.width,photo.height,demoSeed||null])).rows[0];await audit(db,actorId,'gallery.photo_added',id,{employeeId,byteSize:photo.bytes.byteLength,demoOnly:Boolean(demoSeed)});return photoDTO(r);
 });
}
export async function photoResponse(id:string,req:Request,admin=false){
 if(!/^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$/i.test(id))fail(404,'PHOTO_NOT_FOUND','الصورة غير موجودة');const r=(await pool.query('SELECT p.*,e.active,e.user_id,u.role FROM rayeq_work_photos p JOIN rayeq_employees e ON e.id=p.employee_id LEFT JOIN rayeq_users u ON u.id=e.user_id WHERE p.id=$1',[id])).rows[0];if(!r)fail(404,'PHOTO_NOT_FOUND','الصورة غير موجودة');
 if(!admin){let allowed=r.active&&r.role==='worker'&&!r.demo_seed;if(r.active&&r.demo_seed){const c=(await pool.query("SELECT value FROM rayeq_settings WHERE key='config'")).rows[0]?.value,m=(await pool.query('SELECT value FROM rayeq_settings WHERE key=$1',['demo:'+r.demo_seed])).rows[0]?.value;allowed=Boolean(c?.isDemo&&c.demoPilot?.enabled&&c.demoPilot.seedId===r.demo_seed&&Date.parse(c.demoPilot.expiresAt)>Date.now()&&m&&(r.employee_id===m.employeeId?r.user_id===m.workerUserId:(m.nearbyVirtualEmployeeIds||[]).includes(r.employee_id)&&r.user_id===null));}if(!allowed)fail(404,'PHOTO_NOT_FOUND','الصورة غير موجودة');}
 const etag='"'+r.id+'"',headers={'Content-Type':'image/webp','Content-Disposition':'inline; filename="work.webp"','X-Content-Type-Options':'nosniff','Cache-Control':admin?'private, no-store':'public, max-age=0, must-revalidate','X-Robots-Tag':'noindex, nofollow','ETag':etag};if(req.headers.get('if-none-match')===etag)return new Response(null,{status:304,headers});return new Response(new Uint8Array(r.image_bytes),{headers});
}
