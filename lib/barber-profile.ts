import {z} from 'zod';
import sharp from 'sharp';
import {pool,tx,audit,DB} from './db';
import {User,fail,rateLimit} from './auth';
import {readWorkPhoto,employeeDemoSeed,galleryLimits} from './gallery-storage';
import {publicBarberFields,publicImageStorageBytes} from './barber-profile-data';
const uuid=z.string().uuid();
const specialties=z.array(z.string().trim().min(1).max(80)).max(12);
export const publicBarberPatch=z.object({titleAr:z.string().trim().max(100).optional(),titleEn:z.string().trim().max(100).optional(),bioAr:z.string().trim().max(1500).optional(),bioEn:z.string().trim().max(1500).optional(),yearsExperience:z.number().int().min(0).max(80).nullable().optional(),specialtiesAr:specialties.optional(),specialtiesEn:specialties.optional()}).strict().refine(p=>Object.keys(p).length>0);
const ok=(data:unknown)=>Response.json({data});
async function target(u:User,id?:string){
 if(id&&!uuid.safeParse(id).success)fail(404,'BARBER_NOT_FOUND','الحلاق غير موجود');
 const r=(await pool.query('SELECT e.*,u.role FROM rayeq_employees e LEFT JOIN rayeq_users u ON u.id=e.user_id WHERE '+(id?'e.id=$1':'e.user_id=$1'),[id||u.id])).rows[0];
 if(!r)fail(404,'BARBER_NOT_FOUND','الحلاق غير موجود');
 if(u.role!=='admin'&&(!r.active||r.user_id!==u.id||r.role!=='worker'))fail(403,'WORKER_NOT_ACTIVE','حساب العامل غير مفعّل');
 const seed=await employeeDemoSeed(pool,r.id);
 if(seed&&u.role!=='admin'){const c=(await pool.query("SELECT value FROM rayeq_settings WHERE key='config'")).rows[0]?.value;if(!c?.isDemo||!c.demoPilot?.enabled||c.demoPilot.seedId!==seed||Date.parse(c.demoPilot.expiresAt)<=Date.now())fail(409,'DEMO_EXPIRED','التجربة غير متاحة حالياً');}
 return {...r,demoSeed:seed};
}
async function lockOwner(db:DB,u:User,id:string){const row=(await db.query('SELECT e.active,e.user_id,u.role FROM rayeq_employees e LEFT JOIN rayeq_users u ON u.id=e.user_id WHERE e.id=$1 FOR UPDATE OF e',[id])).rows[0];if(!row)fail(404,'BARBER_NOT_FOUND','الحلاق غير موجود');if(u.role!=='admin'&&(!row.active||row.user_id!==u.id||row.role!=='worker'))fail(403,'WORKER_NOT_ACTIVE','حساب العامل غير مفعّل');}
async function ownDTO(e:any){return {employeeId:e.id,nameAr:e.name,nameEn:e.name_en||'',demoOnly:Boolean(e.demoSeed),...await publicBarberFields(pool,e.id)}}
export async function barberProfileRoute(req:Request,path:string,u:User,readBody:<T>(req:Request,s:z.ZodType<T>)=>Promise<T>):Promise<Response|undefined>{
 const m=path.match(/^\/admin\/employees\/([^/]+)\/public-profile(\/portrait)?$/),worker=path.match(/^\/worker\/public-profile(\/portrait)?$/);
 if(!m&&!worker)return;
 if(m&&u.role!=='admin')fail(403,'FORBIDDEN','غير مصرح');if(worker&&u.role!=='worker')fail(403,'WORKER_ONLY','متاح للعامل المفعّل فقط');
 const e=await target(u,m?.[1]),portrait=Boolean(m?.[2]||worker?.[1]);
 if(!portrait&&req.method==='GET')return ok(await ownDTO(e));
 if(!portrait&&req.method==='PATCH'){
  const p=await readBody(req,publicBarberPatch);await rateLimit('public-profile:'+u.id,30,3600);
  const columns:Record<string,string>={titleAr:'title_ar',titleEn:'title_en',bioAr:'bio_ar',bioEn:'bio_en',yearsExperience:'years_experience',specialtiesAr:'specialties_ar',specialtiesEn:'specialties_en'};
  await tx(async db=>{await lockOwner(db,u,e.id);await db.query('INSERT INTO rayeq_barber_profiles(employee_id,demo_seed) VALUES($1,$2) ON CONFLICT DO NOTHING',[e.id,e.demoSeed||null]);const entries=Object.entries(p),values=entries.map(([,v])=>v);await db.query('UPDATE rayeq_barber_profiles SET '+entries.map(([k],i)=>columns[k]+'=$'+(i+2)).join(',')+',updated_at=now() WHERE employee_id=$1',[e.id,...values]);await audit(db,u.id,'barber.public_profile_updated',e.id,{fields:Object.keys(p)});});
  return ok(await ownDTO(e));
 }
 if(portrait&&req.method==='PUT'){
  await rateLimit('public-portrait:'+u.id,10,3600);const photo=await readWorkPhoto(req),bytes=await sharp(photo.bytes).resize(512,512,{fit:'inside',withoutEnlargement:true}).webp({quality:82}).toBuffer();
  if(bytes.length>galleryLimits.maxOutputBytes)fail(400,'INVALID_IMAGE','حجم الصورة أكبر من المسموح');
  await tx(async db=>{await db.query("SELECT pg_advisory_xact_lock(hashtextextended('rayeq-gallery-storage',0))");await lockOwner(db,u,e.id);const old=Number((await db.query('SELECT COALESCE(octet_length(portrait_bytes),0) bytes FROM rayeq_barber_profiles WHERE employee_id=$1',[e.id])).rows[0]?.bytes||0);if(await publicImageStorageBytes(db)-old+bytes.length>galleryLimits.maxStorageBytes)fail(507,'GALLERY_STORAGE_FULL','مساحة الصور ممتلئة، تواصل مع الإدارة');await db.query('INSERT INTO rayeq_barber_profiles(employee_id,portrait_bytes,portrait_version,demo_seed) VALUES($1,$2,1,$3) ON CONFLICT(employee_id) DO UPDATE SET portrait_bytes=$2,portrait_version=rayeq_barber_profiles.portrait_version+1,updated_at=now()',[e.id,bytes,e.demoSeed||null]);await audit(db,u.id,'barber.public_portrait_updated',e.id,{bytes:bytes.length});});
  return ok(await ownDTO(e));
 }
 if(portrait&&req.method==='DELETE'){await tx(async db=>{await lockOwner(db,u,e.id);await db.query('UPDATE rayeq_barber_profiles SET portrait_bytes=NULL,portrait_version=portrait_version+1,updated_at=now() WHERE employee_id=$1',[e.id]);await audit(db,u.id,'barber.public_portrait_removed',e.id)});return new Response(null,{status:204});}
 fail(405,'METHOD_NOT_ALLOWED','الطريقة غير متاحة');
}
export async function publicPortraitResponse(id:string){
 if(!uuid.safeParse(id).success)fail(404,'PORTRAIT_NOT_FOUND','الصورة غير موجودة');
 const r=(await pool.query('SELECT p.portrait_bytes,p.demo_seed,e.active,e.user_id,u.role FROM rayeq_barber_profiles p JOIN rayeq_employees e ON e.id=p.employee_id LEFT JOIN rayeq_users u ON u.id=e.user_id WHERE p.employee_id=$1',[id])).rows[0];
 if(!r?.portrait_bytes||!r.active)fail(404,'PORTRAIT_NOT_FOUND','الصورة غير موجودة');
 const seed=await employeeDemoSeed(pool,id);
 let allowed=r.role==='worker'&&!seed&&!r.demo_seed;
 if(seed&&seed===r.demo_seed){const c=(await pool.query("SELECT value FROM rayeq_settings WHERE key='config'")).rows[0]?.value,m=(await pool.query('SELECT value FROM rayeq_settings WHERE key=$1',['demo:'+seed])).rows[0]?.value;allowed=Boolean(c?.isDemo&&c.demoPilot?.enabled&&c.demoPilot.seedId===seed&&Date.parse(c.demoPilot.expiresAt)>Date.now()&&m&&(id===m.employeeId?r.user_id===m.workerUserId:(m.nearbyVirtualEmployeeIds||[]).includes(id)&&r.user_id===null));}
 if(!allowed)fail(404,'PORTRAIT_NOT_FOUND','الصورة غير موجودة');
 return new Response(new Uint8Array(r.portrait_bytes),{headers:{'Content-Type':'image/webp','Cache-Control':'no-store','X-Content-Type-Options':'nosniff','X-Robots-Tag':'noindex, nofollow'}});
}
