import {z} from 'zod';
import {randomUUID} from 'node:crypto';
import {pool,tx,audit} from './db';
import {User,fail,passwordHash,rateLimit} from './auth';
import {employeeDemoSeed} from './gallery-storage';
const uuid=z.string().uuid();
const ok=(data:unknown,status=200)=>Response.json({data},{status});
export async function adminOperations(req:Request,path:string,u:User,body:<T>(r:Request,s:z.ZodType<T>)=>Promise<T>):Promise<Response|undefined>{
 if(u.role!=='admin')fail(403,'FORBIDDEN','غير مصرح');
 let m=path.match(/^\/admin\/employees\/([^/]+)\/login$/);
 if(m&&req.method==='PATCH'){
  const p=await body(req,z.object({password:z.string().min(10).max(128),confirmIdentity:z.literal(true)}).strict());if(!uuid.safeParse(m[1]).success)fail(404,'NOT_FOUND','الموظف غير موجود');await rateLimit('staff-provision:'+u.id,15,3600);
  await tx(async db=>{const e=(await db.query('SELECT * FROM rayeq_employees WHERE id=$1 FOR UPDATE',[m![1]])).rows[0];if(!e?.user_id)fail(404,'NOT_FOUND','حساب العامل غير موجود');if(await employeeDemoSeed(db,e.id))fail(409,'DEMO_PROTECTED','حساب التجربة محمي');const account=(await db.query('SELECT * FROM rayeq_users WHERE id=$1 FOR UPDATE',[e.user_id])).rows[0];if(account?.role!=='worker'||!account.staff_managed_login)fail(409,'SELF_MANAGED_ACCOUNT','الحساب ذاتي التسجيل. استخدم استعادة كلمة المرور من البريد');await db.query('UPDATE rayeq_users SET password_hash=$1 WHERE id=$2',[passwordHash(p.password),account.id]);await db.query('DELETE FROM rayeq_sessions WHERE user_id=$1',[account.id]);await audit(db,u.id,'employee.login_password_reset',e.id,{sessionsRevoked:true});});return ok({updated:true,sessionsRevoked:true});
 }
 if(m&&req.method==='POST'){
  const p=await body(req,z.object({email:z.string().trim().toLowerCase().email().max(254),password:z.string().min(10).max(128),confirmIdentity:z.literal(true)}).strict());
  if(!uuid.safeParse(m[1]).success)fail(404,'NOT_FOUND','الموظف غير موجود');
  await rateLimit('staff-provision:'+u.id,15,3600);
  const id=await tx(async db=>{
   await db.query('SELECT pg_advisory_xact_lock(hashtextextended($1,0))',[p.email]);
   const e=(await db.query('SELECT * FROM rayeq_employees WHERE id=$1 FOR UPDATE',[m![1]])).rows[0];
   if(!e)fail(404,'NOT_FOUND','الموظف غير موجود');
   if(await employeeDemoSeed(db,e.id))fail(409,'DEMO_PROTECTED','حسابات التجربة محمية');
   if(e.user_id)fail(409,'ALREADY_LINKED','الموظف مربوط بحساب. لا يمكن استبداله من هذا النموذج');
   if(!e.active||!e.service_ids.length||!e.area_ids.length)fail(409,'INVALID_EMPLOYEE','حدد موظفاً نشطاً بخدمات ومناطق أولاً');
   if((await db.query('SELECT id FROM rayeq_users WHERE email=$1',[p.email])).rowCount)fail(409,'EMAIL_EXISTS','البريد مسجل بالفعل. استخدم طلب العامل لربط حسابه، ولا تنشئ حساباً بديلاً');
   const id=randomUUID();
   await db.query("INSERT INTO rayeq_users(id,name,email,password_hash,role,email_verified,staff_managed_login) VALUES($1,$2,$3,$4,'worker',false,true)",[id,e.name,p.email,passwordHash(p.password)]);
   await db.query('UPDATE rayeq_employees SET user_id=$1 WHERE id=$2',[id,e.id]);
   await audit(db,u.id,'employee.login_created',e.id,{userId:id,identityConfirmedByAdmin:true,emailOwnershipVerified:false});return id;
  });return ok({id,role:'worker',emailVerified:false,staffManagedLogin:true},201);
 }
 m=path.match(/^\/admin\/(services|areas|employees)\/([^/]+)$/);
 if(m&&req.method==='DELETE'){
  if(!uuid.safeParse(m[2]).success)fail(404,'NOT_FOUND','العنصر غير موجود');
  const type=m[1],id=m[2];
  await tx(async db=>{
   // Serialize removals against qualifications and bookings that take row locks.
   const row=(await db.query(`SELECT * FROM rayeq_${type} WHERE id=$1 FOR UPDATE`,[id])).rows[0];if(!row)fail(404,'NOT_FOUND','العنصر غير موجود');
   const manifests=(await db.query("SELECT value FROM rayeq_settings WHERE key LIKE 'demo:%'")).rows;
   if(manifests.some(r=>JSON.stringify(r.value).includes(id)))fail(409,'DEMO_PROTECTED','بيانات التجربة محمية حتى الموافقة على مسحها');
   let used=false;
   if(type==='employees')used=Boolean(row.user_id||(await db.query('SELECT 1 FROM rayeq_bookings WHERE employee_id=$1 UNION ALL SELECT 1 FROM rayeq_payroll WHERE employee_id=$1 UNION ALL SELECT 1 FROM rayeq_work_photos WHERE employee_id=$1 LIMIT 1',[id])).rowCount);
   else{const field=type==='services'?'service_ids':'area_ids',doc=type==='services'?'service':'area';used=Boolean((await db.query(`SELECT 1 FROM rayeq_employees WHERE $1=ANY(${field}) UNION ALL SELECT 1 FROM rayeq_bookings WHERE document->$2->>'id'=$1::text LIMIT 1`,[id,doc])).rowCount);}
   if(used)fail(409,'RECORD_IN_USE','العنصر مرتبط بسجلات أخرى. أوقفه بدلاً من حذفه لحفظ التاريخ');
   await db.query(`DELETE FROM rayeq_${type} WHERE id=$1`,[id]);await audit(db,u.id,type+'.deleted',id,{name:row.name||row.name_ar});
  });return new Response(null,{status:204});
 }
 if(path==='/admin/customers'&&req.method==='GET'){
  const q=(new URL(req.url).searchParams.get('q')||'').trim();if(q.length<2)return ok({items:[]});
  const rows=(await pool.query("SELECT id,name,email,email_verified FROM rayeq_users WHERE role='customer' AND (name ILIKE $1 OR email ILIKE $1) ORDER BY name LIMIT 25",['%'+q.slice(0,100)+'%'])).rows;
  return ok({items:rows});
 }
}
