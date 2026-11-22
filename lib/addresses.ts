import {z} from 'zod';
import {randomUUID} from 'node:crypto';
import {pool,tx,audit} from './db';
import {User,fail} from './auth';
export const addressFields=z.object({street:z.string().trim().min(1).max(200),building:z.string().trim().min(1).max(100),floor:z.string().trim().max(50).optional(),apartment:z.string().trim().max(50).optional(),workplaceName:z.string().trim().max(150).optional(),directions:z.string().trim().max(500).optional()}).strict();
const baseSchema=z.object({label:z.string().trim().min(1).max(80),locationType:z.enum(['home','work']),address:addressFields}).strict();
const schema=baseSchema.refine(x=>x.locationType!=='work'||Boolean(x.address.workplaceName),{message:'Workplace required',path:['address','workplaceName']});
const dto=(r:any)=>({id:r.id,...r.document,version:r.version,updatedAt:r.updated_at});
export async function addressesRoute(req:Request,path:string,u:User,body:<T>(r:Request,s:z.ZodType<T>)=>Promise<T>){
 const m=path.match(/^\/addresses(?:\/([^/]+))?$/);if(!m)return;
 if(u.role!=='customer')fail(403,'CUSTOMER_ONLY','العناوين المحفوظة لحساب العميل فقط');
 const id=m[1];if(id&&!z.string().uuid().safeParse(id).success)fail(404,'NOT_FOUND','العنوان غير موجود');
 if(!id&&req.method==='GET')return Response.json({data:{items:(await pool.query('SELECT * FROM rayeq_addresses WHERE user_id=$1 ORDER BY updated_at DESC,id',[u.id])).rows.map(dto)}});
 if((!id&&req.method==='POST')||(id&&req.method==='PATCH')){
  const p=await body(req,id?baseSchema.extend({version:z.number().int().positive()}).refine(x=>x.locationType!=='work'||Boolean(x.address.workplaceName)):schema);
  return tx(async db=>{await db.query('SELECT id FROM rayeq_users WHERE id=$1 FOR UPDATE',[u.id]);
   let row:any;
   if(id){const {version,...data}=p as z.infer<typeof schema>&{version:number};row=(await db.query('UPDATE rayeq_addresses SET document=$1,version=version+1,updated_at=now() WHERE id=$2 AND user_id=$3 AND version=$4 RETURNING *',[JSON.stringify(data),id,u.id,version])).rows[0];if(!row){const exists=(await db.query('SELECT id FROM rayeq_addresses WHERE id=$1 AND user_id=$2',[id,u.id])).rowCount;if(!exists)fail(404,'NOT_FOUND','العنوان غير موجود');fail(409,'VERSION_CONFLICT','تم تعديل العنوان، حدّث القائمة');}}
   else{if((await db.query('SELECT count(*)::int n FROM rayeq_addresses WHERE user_id=$1',[u.id])).rows[0].n>=20)fail(409,'ADDRESS_LIMIT','الحد الأقصى 20 عنواناً');row=(await db.query('INSERT INTO rayeq_addresses(id,user_id,document) VALUES($1,$2,$3) RETURNING *',[randomUUID(),u.id,JSON.stringify(p)])).rows[0];}
   await audit(db,u.id,'address.saved',row.id);return Response.json({data:dto(row)},{status:id?200:201});
  });
 }
 if(id&&req.method==='DELETE'){
  const p=await body(req,z.object({version:z.number().int().positive()}).strict());
  return tx(async db=>{const row=(await db.query('SELECT * FROM rayeq_addresses WHERE id=$1 AND user_id=$2 FOR UPDATE',[id,u.id])).rows[0];if(!row)fail(404,'NOT_FOUND','العنوان غير موجود');if(row.version!==p.version)fail(409,'VERSION_CONFLICT','تم تعديل العنوان، حدّث القائمة');await db.query('DELETE FROM rayeq_addresses WHERE id=$1',[id]);await audit(db,u.id,'address.deleted',id);return new Response(null,{status:204});});
 }
 fail(405,'METHOD_NOT_ALLOWED','طريقة غير مدعومة');
}
