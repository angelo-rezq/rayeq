import {DateTime} from 'luxon';
import {pool,tx,audit} from '../lib/db';
const seedId='rayeq-pilot-20261122';
const key='demo:'+seedId;
const serviceIds=['d0e00000-0000-4000-8000-000000000001','d0e00000-0000-4000-8000-000000000002'];
const areaIds=['d0e00000-0000-4000-8000-000000000101'];
async function main(){console.log(await tx(async db=>{
 const prior=(await db.query('SELECT value FROM rayeq_settings WHERE key=$1 FOR UPDATE',[key])).rows[0];if(prior)return {alreadySeeded:true,...prior.value};
 const c=(await db.query("SELECT value FROM rayeq_settings WHERE key='config' FOR UPDATE")).rows[0]?.value;
 if(!c?.isDemo||c.intakeEnabled||c.demoPilot)throw Error('Expected a closed, unseeded pilot');
 const users=(await db.query('SELECT id,email,role,email_verified FROM rayeq_users WHERE email=ANY($1::text[])',[['angluosr@gmail.com','customer-test@rayeq.invalid','worker-test@rayeq.invalid']])).rows;
 const admin=users.find(r=>r.email==='angluosr@gmail.com'&&r.role==='admin');
 const customer=users.find(r=>r.email==='customer-test@rayeq.invalid'&&r.role==='customer'&&r.email_verified);
 const worker=users.find(r=>r.email==='worker-test@rayeq.invalid'&&r.role==='worker'&&r.email_verified);
 if(!admin||!customer||!worker)throw Error('Verified pilot identities missing');
 const employee=(await db.query('SELECT * FROM rayeq_employees WHERE user_id=$1 AND active FOR UPDATE',[worker.id])).rows[0];if(!employee)throw Error('Active test employee missing');
 if((await db.query('SELECT id FROM rayeq_services WHERE id=ANY($1::uuid[])',[serviceIds])).rowCount||(await db.query('SELECT id FROM rayeq_areas WHERE id=ANY($1::uuid[])',[areaIds])).rowCount)throw Error('Seed identifier collision');
 for(const[id,name,duration]of [[serviceIds[0],'خدمة تجريبية مجانية: قص شعر',30],[serviceIds[1],'خدمة تجريبية مجانية: تهذيب ذقن',20]])await db.query('INSERT INTO rayeq_services(id,name_ar,description_ar,category,duration_minutes,price_minor,active,image_url) VALUES($1,$2,$3,$4,$5,0,true,$6)',[id,name,'بيانات اختبار فقط. لا توجد زيارة أو خدمة حقيقية ولا تحصيل أموال.','تجربة مجانية',duration,'https://rayeq-platform.onrender.com/mobile-demo/assets/assets/images/grooming.webp']);
 await db.query('INSERT INTO rayeq_areas(id,name_ar,travel_fee_minor,active) VALUES($1,$2,0,true)',[areaIds[0],'منطقة تجريبية - بدون زيارة حقيقية']);
 await db.query('UPDATE rayeq_employees SET service_ids=$1,area_ids=$2 WHERE id=$3',[serviceIds,areaIds,employee.id]);
 const expiresAt=DateTime.now().setZone('Africa/Cairo').plus({days:7}).toUTC().toISO();
 const manifest={seedId,serviceIds,areaIds,customerId:customer.id,workerUserId:worker.id,employeeId:employee.id,previousServiceIds:employee.service_ids,previousAreaIds:employee.area_ids,createdAt:new Date().toISOString(),expiresAt};
 c.demoPilot={enabled:true,seedId,customerIds:[customer.id],serviceIds,areaIds,expiresAt};
 await db.query("UPDATE rayeq_settings SET value=$1 WHERE key='config'",[JSON.stringify(c)]);
 await db.query('INSERT INTO rayeq_settings(key,value) VALUES($1,$2)',[key,JSON.stringify(manifest)]);
 await audit(db,admin.id,'DEMO_SEEDED',seedId,{serviceIds,areaIds,employeeId:employee.id,publicIntakeEnabled:false,expiresAt});
 return {seeded:true,...manifest};
}));}
main().catch(e=>{console.error(e.message);process.exitCode=1}).finally(()=>pool.end());
