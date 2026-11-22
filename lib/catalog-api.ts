import {z} from 'zod';
import {randomUUID} from 'node:crypto';
import {pool,tx,audit} from './db';
import {fail,User,ApiError} from './auth';
const uuid=z.string().uuid();
const text=(max:number)=>z.string().trim().min(1).max(max);
const english=(max:number)=>z.string().trim().max(max).nullable().optional();
const imageUrl=z.string().trim().max(2000).url().refine(value=>{try{const u=new URL(value);return u.protocol==='https:'&&!u.username&&!u.password}catch{return false}}).nullable().optional();
export const serviceSchema=z.object({nameAr:text(150),nameEn:english(150),descriptionAr:z.string().trim().max(1000),descriptionEn:english(1000),category:text(100),categoryEn:english(100),durationMinutes:z.number().int().min(5).max(480),priceMinor:z.number().int().min(0).max(10_000_000),active:z.boolean(),imageUrl,version:z.number().int().optional()}).strict();
export const areaSchema=z.object({nameAr:text(150),nameEn:english(150),travelFeeMinor:z.number().int().min(0).max(10_000_000),active:z.boolean(),version:z.number().int().optional()}).strict();
export const serviceDTO=(s:any)=>({id:s.id,nameAr:s.name_ar,nameEn:s.name_en||'',descriptionAr:s.description_ar,descriptionEn:s.description_en||'',category:s.category,categoryEn:s.category_en||'',englishReady:Boolean(s.name_en&&s.category_en&&(!s.description_ar||s.description_en)),durationMinutes:s.duration_minutes,priceMinor:s.price_minor,version:s.version,active:s.active,imageUrl:s.image_url||null});
export const areaDTO=(a:any)=>({id:a.id,nameAr:a.name_ar,nameEn:a.name_en||'',englishReady:Boolean(a.name_en),travelFeeMinor:a.travel_fee_minor,version:a.version,active:a.active});
async function body<T>(req:Request,schema:z.ZodType<T>):Promise<T>{if(Number(req.headers.get('content-length')||0)>32000)fail(413,'BODY_TOO_LARGE','حجم البيانات أكبر من المسموح');const raw=await req.text();if(raw.length>32000)fail(413,'BODY_TOO_LARGE','حجم البيانات أكبر من المسموح');let value;try{value=JSON.parse(raw)}catch{fail(400,'INVALID_JSON','البيانات غير صالحة')}const parsed=schema.safeParse(value);if(!parsed.success){const fields:Record<string,string>={};for(const issue of parsed.error.issues)fields[issue.path.join('.')]='تحقق من هذا الحقل';throw new ApiError(400,'VALIDATION_ERROR','راجع البيانات المطلوبة',fields)}return parsed.data;}
export async function catalogAdminRoute(req:Request,path:string,u:User):Promise<Response|undefined>{
 const method=req.method;
 if(path==='/admin/catalog'&&method==='GET'){const[s,a]=await Promise.all([pool.query('SELECT * FROM rayeq_services ORDER BY name_ar'),pool.query('SELECT * FROM rayeq_areas ORDER BY name_ar')]);return Response.json({data:{services:s.rows.map(serviceDTO),areas:a.rows.map(areaDTO)}});}
 const m=path.match(/^\/admin\/(services|areas)(?:\/([^/]+))?$/);if(!m||!['POST','PATCH'].includes(method))return;
 const type=m[1],id=m[2]||randomUUID();
 if(!uuid.safeParse(id).success)fail(404,'NOT_FOUND','العنصر غير موجود');
 if(method==='POST'&&m[2])fail(405,'METHOD_NOT_ALLOWED','طريقة غير مدعومة');
 if(method==='PATCH'&&!m[2])fail(400,'ID_REQUIRED','حدد العنصر');
 if(type==='services'){
  const p=await body(req,serviceSchema);
  await tx(async db=>{
   if(method==='POST')await db.query('INSERT INTO rayeq_services(id,name_ar,name_en,description_ar,description_en,category,category_en,duration_minutes,price_minor,active,image_url) VALUES($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11)',[id,p.nameAr,p.nameEn||'',p.descriptionAr,p.descriptionEn||'',p.category,p.categoryEn||'',p.durationMinutes,p.priceMinor,p.active,p.imageUrl||null]);
   else{const previous=(await db.query('SELECT * FROM rayeq_services WHERE id=$1 FOR UPDATE',[id])).rows[0];if(!previous||previous.version!==p.version)fail(409,'VERSION_CONFLICT','تم تعديل العنصر، حدّث الصفحة');await db.query('UPDATE rayeq_services SET name_ar=$2,name_en=$3,description_ar=$4,description_en=$5,category=$6,category_en=$7,duration_minutes=$8,price_minor=$9,active=$10,image_url=$11,version=version+1 WHERE id=$1',[id,p.nameAr,p.nameEn===undefined?previous.name_en:p.nameEn||'',p.descriptionAr,p.descriptionEn===undefined?previous.description_en:p.descriptionEn||'',p.category,p.categoryEn===undefined?previous.category_en:p.categoryEn||'',p.durationMinutes,p.priceMinor,p.active,p.imageUrl===undefined?previous.image_url:p.imageUrl]);}
   await audit(db,u.id,'service.saved',id,p);
  });
  return Response.json({data:serviceDTO((await pool.query('SELECT * FROM rayeq_services WHERE id=$1',[id])).rows[0])},{status:method==='POST'?201:200});
 }
 const p=await body(req,areaSchema);
 await tx(async db=>{
  if(method==='POST')await db.query('INSERT INTO rayeq_areas(id,name_ar,name_en,travel_fee_minor,active) VALUES($1,$2,$3,$4,$5)',[id,p.nameAr,p.nameEn||'',p.travelFeeMinor,p.active]);
  else{const previous=(await db.query('SELECT * FROM rayeq_areas WHERE id=$1 FOR UPDATE',[id])).rows[0];if(!previous||previous.version!==p.version)fail(409,'VERSION_CONFLICT','تم تعديل العنصر، حدّث الصفحة');await db.query('UPDATE rayeq_areas SET name_ar=$2,name_en=$3,travel_fee_minor=$4,active=$5,version=version+1 WHERE id=$1',[id,p.nameAr,p.nameEn===undefined?previous.name_en:p.nameEn||'',p.travelFeeMinor,p.active]);}
  await audit(db,u.id,'area.saved',id,p);
 });
 return Response.json({data:areaDTO((await pool.query('SELECT * FROM rayeq_areas WHERE id=$1',[id])).rows[0])},{status:method==='POST'?201:200});
}
