import {z} from 'zod';
import sharp from 'sharp';
import {pool,tx,audit} from './db';
import {fail,User,rateLimit} from './auth';
const origin=()=>String(process.env.PUBLIC_ORIGIN||process.env.RENDER_EXTERNAL_URL||'').replace(/\/$/,'');
const ok=(data:unknown)=>Response.json({data});
export async function profileFor(u:User){
 const row=(await pool.query('SELECT u.name,p.phone,p.avatar_version,octet_length(p.avatar_bytes) avatar_size,e.id employee_id,e.name employee_name,e.name_en employee_name_en,e.active,e.service_ids,e.area_ids FROM rayeq_users u LEFT JOIN rayeq_profiles p ON p.user_id=u.id LEFT JOIN rayeq_employees e ON e.user_id=u.id WHERE u.id=$1',[u.id])).rows[0];
 if(!row)fail(404,'NOT_FOUND','الحساب غير موجود');
 return {...u,name:row.name,displayNameEn:row.employee_name_en||'',phone:row.phone||'',avatarUrl:row.avatar_size?origin()+'/api/v1/profile/avatar?v='+row.avatar_version:null,...(row.employee_id?{workerProfile:{employeeId:row.employee_id,employeeName:row.employee_name,employeeNameEn:row.employee_name_en||'',active:row.active,serviceIds:row.service_ids,areaIds:row.area_ids}}:{})};
}
let encoding=false;
export async function profileRoute(req:Request,u:User,path:string):Promise<Response|undefined>{
 if(path==='/profile'&&req.method==='GET')return ok(await profileFor(u));
 if(path==='/profile'&&req.method==='PATCH'){
  const raw=await req.text();if(raw.length>2000)fail(413,'BODY_TOO_LARGE','البيانات أكبر من المسموح');
  let value;try{value=JSON.parse(raw)}catch{fail(400,'INVALID_JSON','البيانات غير صالحة')}
  const parsed=z.object({name:z.string().trim().min(1).max(100).optional(),phone:z.string().trim().max(20).refine(v=>v===''||/^\+?[0-9 ()-]{8,20}$/.test(v)).optional()}).strict().refine(v=>v.name!==undefined||v.phone!==undefined).safeParse(value);
  if(!parsed.success)fail(400,'VALIDATION_ERROR','راجع الاسم ورقم التواصل');
  const p=parsed.data;
  await tx(async db=>{
   if(p.name!==undefined)await db.query('UPDATE rayeq_users SET name=$1 WHERE id=$2',[p.name,u.id]);
   if(p.phone!==undefined){await db.query('INSERT INTO rayeq_profiles(user_id,phone) VALUES($1,$2) ON CONFLICT(user_id) DO UPDATE SET phone=$2,updated_at=now()',[u.id,p.phone]);if(u.role==='worker')await db.query('UPDATE rayeq_employees SET phone=$1 WHERE user_id=$2',[p.phone,u.id]);}
   await audit(db,u.id,'profile.updated',u.id,{nameChanged:p.name!==undefined,phoneChanged:p.phone!==undefined});
  });return ok(await profileFor(u));
 }
 if(path==='/profile/avatar'&&req.method==='GET'){
  const row=(await pool.query('SELECT avatar_bytes FROM rayeq_profiles WHERE user_id=$1',[u.id])).rows[0];if(!row?.avatar_bytes)fail(404,'AVATAR_NOT_FOUND','لم تضف صورة للحساب');
  return new Response(new Uint8Array(row.avatar_bytes),{headers:{'Content-Type':'image/webp','Cache-Control':'private, no-store','Content-Disposition':'inline','X-Content-Type-Options':'nosniff'}});
 }
 if(path==='/profile/avatar'&&req.method==='DELETE'){
  await tx(async db=>{await db.query('UPDATE rayeq_profiles SET avatar_bytes=NULL,avatar_version=avatar_version+1,updated_at=now() WHERE user_id=$1',[u.id]);await audit(db,u.id,'profile.avatar_removed',u.id)});return new Response(null,{status:204});
 }
 if(path==='/profile/avatar'&&req.method==='PUT'){
  await rateLimit('avatar:'+u.id,10,3600);
  const mime=(req.headers.get('content-type')||'').split(';')[0].toLowerCase();
  const formats:Record<string,string>={'image/jpeg':'jpeg','image/png':'png','image/webp':'webp'};
  if(!formats[mime])fail(415,'UNSUPPORTED_IMAGE_TYPE','اختر صورة JPEG أو PNG أو WebP');
  const max=2*1024*1024;
  if(Number(req.headers.get('content-length')||0)>max)fail(413,'IMAGE_TOO_LARGE','الحد الأقصى للصورة 2 ميجابايت');
  const reader=req.body?.getReader();if(!reader)fail(400,'INVALID_IMAGE','أضف صورة صحيحة');
  const chunks:Uint8Array[]=[];let size=0;
  while(true){const part=await reader.read();if(part.done)break;size+=part.value.byteLength;if(size>max){await reader.cancel();fail(413,'IMAGE_TOO_LARGE','الحد الأقصى للصورة 2 ميجابايت')}chunks.push(part.value)}
  if(!size)fail(400,'INVALID_IMAGE','أضف صورة صحيحة');
  if(encoding)fail(429,'IMAGE_PROCESSOR_BUSY','حاول رفع الصورة بعد لحظات');encoding=true;
  let output:Buffer;
  try{
   const input=Buffer.concat(chunks);const meta=await sharp(input,{limitInputPixels:16_777_216,failOn:'warning'}).metadata();
   if(meta.format!==formats[mime]||(meta.pages||1)>1)throw Error('Invalid image format');
   output=await sharp(input,{limitInputPixels:16_777_216,failOn:'warning'}).rotate().resize(512,512,{fit:'inside',withoutEnlargement:true}).webp({quality:82}).toBuffer();
   if(output.byteLength>512*1024)throw Error('Output too large');
  }catch{fail(400,'INVALID_IMAGE','تعذر قراءة الصورة، اختر صورة ثابتة سليمة لا تتجاوز 16 ميجابكسل')}finally{encoding=false}
  await tx(async db=>{await db.query('INSERT INTO rayeq_profiles(user_id,avatar_bytes,avatar_version) VALUES($1,$2,1) ON CONFLICT(user_id) DO UPDATE SET avatar_bytes=$2,avatar_version=rayeq_profiles.avatar_version+1,updated_at=now()',[u.id,output]);await audit(db,u.id,'profile.avatar_updated',u.id,{bytes:output.byteLength})});
  return ok(await profileFor(u));
 }
 return undefined;
}
