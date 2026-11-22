import {galleryFor} from './gallery-storage';
import {z} from 'zod';
import {randomUUID} from 'node:crypto';
import {DB,pool,tx,audit} from './db';
import {User,fail,rateLimit} from './auth';
import {demoDirectory} from './barbers';
import {publicReview,ratingSummaryMany} from './ratings';
const uuid=z.string().uuid(),ok=(data:unknown,status=200)=>Response.json({data},{status});
export async function directoryContext(db:DB,u:User){
 const c=(await db.query("SELECT value FROM rayeq_settings WHERE key='config'")).rows[0].value,demo=await demoDirectory(db,c,u);
 const manifests=(await db.query("SELECT value FROM rayeq_settings WHERE key LIKE 'demo:%'")).rows;
 const demoIds=manifests.flatMap(r=>[r.value.employeeId,...(r.value.nearbyVirtualEmployeeIds||[])]).filter(id=>uuid.safeParse(id).success);
 return{demo,demoIds,demoSeed:demo?.seedId};
}
export async function visibleBarbers(db:DB,u:User,id?:string){
 if(id&&!uuid.safeParse(id).success)fail(404,'BARBER_NOT_FOUND','الحلاق غير موجود');
 const context=await directoryContext(db,u),allowed=context.demo?.barbers.map(b=>b.id)||[];
 const rows=(await db.query("SELECT e.id,e.name,e.name_en FROM rayeq_employees e LEFT JOIN rayeq_users u ON u.id=e.user_id WHERE e.active AND ((u.role='worker' AND NOT(e.id=ANY($1::uuid[]))) OR e.id=ANY($2::uuid[])) AND ($3::uuid IS NULL OR e.id=$3)",[context.demoIds,allowed,id||null])).rows;
 if(id&&!rows.length)fail(404,'BARBER_NOT_FOUND','الحلاق غير موجود');
 return{...context,rows};
}
export function pageQuery(req:Request,alias='r'){
 const params=new URL(req.url).searchParams,limit=Math.min(50,Math.max(1,Math.trunc(Number(params.get('limit')))||20)),cursor=params.get('cursor');let after:any[]=[],clause='';
 if(cursor){try{if(cursor.length>512)throw Error();after=JSON.parse(Buffer.from(cursor,'base64url').toString());if(!Array.isArray(after)||after.length!==2||!Number.isFinite(Date.parse(after[0]))||!uuid.safeParse(after[1]).success)throw Error();clause=` AND (${alias}.created_at,${alias}.id)<($3::timestamptz,$4::uuid)`;}catch{fail(400,'INVALID_CURSOR','مؤشر الصفحة غير صالح')}}return{limit,after,clause};
}
export function pageResult(rows:any[],limit:number){const items=rows.slice(0,limit),last=items.at(-1);return{items,nextCursor:rows.length>limit&&last?Buffer.from(JSON.stringify([last.created_at,last.id])).toString('base64url'):null}}
export async function contentRoute(req:Request,path:string,u:User,readBody:<T>(req:Request,schema:z.ZodType<T>)=>Promise<T>):Promise<Response|undefined>{
 const method=req.method;let m=path.match(/^\/bookings\/([^/]+)\/review$/);
 if(m&&method==='POST'){
  if(u.role!=='customer')fail(403,'CUSTOMER_ONLY','التقييم متاح لصاحب الحجز فقط');if(!uuid.safeParse(m[1]).success)fail(404,'NOT_FOUND','الحجز غير موجود');
  const p=await readBody(req,z.object({rating:z.number().int().min(1).max(5),text:z.string().trim().max(1000).default('')}).strict());await rateLimit('review:'+u.id,20,3600);
  return tx(async db=>{const b=(await db.query('SELECT * FROM rayeq_bookings WHERE id=$1 AND customer_id=$2 FOR UPDATE',[m![1],u.id])).rows[0];if(!b)fail(404,'NOT_FOUND','الحجز غير موجود');if(b.status!=='COMPLETED'||!b.employee_id)fail(409,'REVIEW_NOT_ELIGIBLE','يمكن التقييم بعد اكتمال الخدمة فقط');
   if((await db.query('SELECT id FROM rayeq_reviews WHERE booking_id=$1',[b.id])).rowCount)fail(409,'REVIEW_ALREADY_EXISTS','تم تقييم هذا الحجز من قبل');
   const first=String(u.name||b.document.customerName||'عميل').trim().split(/\s+/)[0],display=/^[\p{L}\p{M}'-]{1,24}$/u.test(first)?first:(Array.from(first).find(c=>/\p{L}/u.test(c))||'ع')+'.';
   const r=(await db.query('INSERT INTO rayeq_reviews(id,booking_id,customer_id,employee_id,rating,text,customer_display_name,demo_seed) VALUES($1,$2,$3,$4,$5,$6,$7,$8) RETURNING *',[randomUUID(),b.id,u.id,b.employee_id,p.rating,p.text,display,b.document.demoSeed||null])).rows[0];await audit(db,u.id,'review.created',r.id,{bookingId:b.id,rating:p.rating,demoOnly:Boolean(r.demo_seed)});return ok(publicReview(r),201);
  });
 }
 if(path==='/worker/rating'&&method==='GET'){
  const e=(await pool.query('SELECT id FROM rayeq_employees WHERE user_id=$1 AND active',[u.id])).rows[0];if(!e)fail(403,'WORKER_NOT_ACTIVE','حساب العامل غير مفعّل');const context=await directoryContext(pool,u);const seed=context.demoIds.includes(e.id)?(await pool.query("SELECT demo_seed FROM rayeq_reviews WHERE employee_id=$1 AND demo_seed IS NOT NULL LIMIT 1",[e.id])).rows[0]?.demo_seed:undefined;return ok({...((await ratingSummaryMany(pool,[e.id],seed))[e.id]),demoOnly:Boolean(seed)});
 }
 if(path==='/barbers/featured'&&method==='GET'){
  const d=await visibleBarbers(pool,u),ratings=await ratingSummaryMany(pool,d.rows.map(r=>r.id),d.demoSeed),limit=Math.min(30,Math.max(1,Math.trunc(Number(new URL(req.url).searchParams.get('limit')))||10));const items=d.rows.map(r=>({id:r.id,nameAr:r.name,nameEn:r.name_en||'',...ratings[r.id],demoOnly:d.demoIds.includes(r.id)})).sort((a,b)=>(b.ratingAverage??-1)-(a.ratingAverage??-1)||b.reviewCount-a.reviewCount||a.nameAr.localeCompare(b.nameAr)).slice(0,limit);return ok({items});
 }
 m=path.match(/^\/barbers\/([^/]+)(\/reviews)?$/);
 if(m&&method==='GET'){
  const d=await visibleBarbers(pool,u,m[1]),barber=d.rows[0],rating=(await ratingSummaryMany(pool,[barber.id],d.demoSeed))[barber.id];
  if(!m[2])return ok({id:barber.id,nameAr:barber.name,nameEn:barber.name_en||'',...rating,demoOnly:d.demoIds.includes(barber.id),gallery:await galleryFor(pool,barber.id,d.demoSeed)});
  const q=pageQuery(req),r=(await pool.query(`SELECT r.* FROM rayeq_reviews r WHERE r.employee_id=$1 AND (r.demo_seed IS NULL OR r.demo_seed=$2) AND NOT r.hidden ${q.clause} ORDER BY r.created_at DESC,r.id DESC LIMIT $${q.after.length?5:3}`,[barber.id,d.demoSeed||null,...q.after,q.limit+1])).rows,page=pageResult(r,q.limit);return ok({...page,items:page.items.map(publicReview),...rating});
 }
 if(path==='/admin/reviews'&&method==='GET'){
  const q=pageQuery(req),visibility=new URL(req.url).searchParams.get('visibility')||'all';if(!['all','hidden','visible'].includes(visibility))fail(400,'VALIDATION_ERROR','اختر حالة صحيحة');
  const rows=(await pool.query(`SELECT r.*,e.name barber_name,e.name_en barber_name_en,b.reference FROM rayeq_reviews r JOIN rayeq_employees e ON e.id=r.employee_id JOIN rayeq_bookings b ON b.id=r.booking_id WHERE ($1='all' OR r.hidden=($1='hidden')) AND $2::text='reviews' ${q.clause} ORDER BY r.created_at DESC,r.id DESC LIMIT $${q.after.length?5:3}`,[visibility,'reviews',...q.after,q.limit+1])).rows,page=pageResult(rows,q.limit);return ok({...page,items:page.items.map(r=>({...publicReview(r),employeeId:r.employee_id,barberNameAr:r.barber_name,barberNameEn:r.barber_name_en||'',bookingId:r.booking_id,bookingReference:r.reference,hidden:r.hidden,moderationReason:r.moderation_reason}))});
 }
 m=path.match(/^\/admin\/reviews\/([^/]+)$/);
 if(m&&method==='PATCH'){
  if(!uuid.safeParse(m[1]).success)fail(404,'REVIEW_NOT_FOUND','التقييم غير موجود');const p=await readBody(req,z.object({hidden:z.boolean(),reason:z.string().trim().max(500).default('')}).strict());await tx(async db=>{const r=await db.query('UPDATE rayeq_reviews SET hidden=$1,moderation_reason=$2,moderated_at=now() WHERE id=$3 RETURNING id',[p.hidden,p.hidden?p.reason:'',m![1]]);if(!r.rowCount)fail(404,'REVIEW_NOT_FOUND','التقييم غير موجود');await audit(db,u.id,'review.moderated',m![1],{hidden:p.hidden,reason:p.reason})});return ok({updated:true});
 }
}
