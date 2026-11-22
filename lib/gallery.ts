import {z} from 'zod';import {pool,tx,audit} from './db';import {User,fail,rateLimit} from './auth';
import {visibleBarbers,pageQuery,pageResult} from './barber-content';
import {galleryFor,employeeDemoSeed,readWorkPhoto,storeWorkPhoto,photoDTO,photoResponse,galleryLimits} from './gallery-storage';
const uuid=z.string().uuid(),ok=(data:unknown,status=200)=>Response.json({data},{status});
export async function galleryRoute(req:Request,path:string,u:User):Promise<Response|undefined>{
 const method=req.method;let m=path.match(/^\/barbers\/([^/]+)\/gallery$/);
 if(m&&method==='GET'){const d=await visibleBarbers(pool,u,m[1]);return ok(await galleryFor(pool,m[1],d.demoSeed));}
 if(path==='/worker/gallery'&&['GET','POST'].includes(method)){
  const e=(await pool.query('SELECT id FROM rayeq_employees WHERE user_id=$1 AND active',[u.id])).rows[0];if(!e)fail(403,'WORKER_NOT_ACTIVE','حساب العامل غير مفعّل');if(method==='GET')return ok(await galleryFor(pool,e.id,undefined,true));
  await rateLimit('gallery-upload:'+u.id,10,3600);const demoSeed=await employeeDemoSeed(pool,e.id),photo=await readWorkPhoto(req);return ok(await storeWorkPhoto(u.id,e.id,photo,demoSeed,u.id),201);
 }
 m=path.match(/^\/(worker|admin)\/gallery\/([^/]+)$/);
 if(m&&method==='DELETE'){
  if(!uuid.safeParse(m[2]).success)fail(404,'PHOTO_NOT_FOUND','الصورة غير موجودة');await tx(async db=>{const r=(await db.query('DELETE FROM rayeq_work_photos p USING rayeq_employees e WHERE p.id=$1 AND e.id=p.employee_id AND ($2::boolean OR e.user_id=$3) RETURNING p.employee_id',[m![2],m![1]==='admin',u.id])).rows[0];if(!r)fail(404,'PHOTO_NOT_FOUND','الصورة غير موجودة');await audit(db,u.id,'gallery.photo_removed',m![2],{employeeId:r.employee_id,admin:m![1]==='admin'})});return new Response(null,{status:204});
 }
 if(path==='/admin/gallery'&&method==='GET'){
  const q=pageQuery(req,'p'),employeeId=new URL(req.url).searchParams.get('employeeId');if(employeeId&&!uuid.safeParse(employeeId).success)fail(400,'VALIDATION_ERROR','اختر موظفاً صحيحاً');
  const rows=(await pool.query(`SELECT p.id,p.employee_id,p.width,p.height,p.byte_size,p.created_at,p.demo_seed,e.name,e.name_en FROM rayeq_work_photos p JOIN rayeq_employees e ON e.id=p.employee_id WHERE ($1::uuid IS NULL OR p.employee_id=$1) AND $2::text='gallery' ${q.clause} ORDER BY p.created_at DESC,p.id DESC LIMIT $${q.after.length?5:3}`,[employeeId||null,'gallery',...q.after,q.limit+1])).rows,page=pageResult(rows,q.limit),used=Number((await pool.query('SELECT COALESCE(sum(byte_size),0)::bigint bytes FROM rayeq_work_photos')).rows[0].bytes);
  return ok({...page,items:page.items.map(r=>({...photoDTO(r),employeeId:r.employee_id,barberNameAr:r.name,barberNameEn:r.name_en||'',adminUrl:'/api/v1/admin/gallery/'+r.id+'/image'})),storage:{bytesUsed:used,maxBytes:galleryLimits.maxStorageBytes},maxPhotosPerBarber:galleryLimits.maxPhotos});
 }
 m=path.match(/^\/admin\/gallery\/([^/]+)\/image$/);if(m&&method==='GET'){if(!uuid.safeParse(m[1]).success)fail(404,'PHOTO_NOT_FOUND','الصورة غير موجودة');return photoResponse(m[1],req,true);}
}
