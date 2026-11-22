import assert from 'node:assert/strict';import {randomUUID} from 'node:crypto';import {writeFile} from 'node:fs/promises';
import {pool} from '../lib/db';import {session,hash} from '../lib/auth';
const base='https://rayeq-platform.onrender.com/api/v1',tokens:string[]=[];let outsider='';
async function main(){
 const seed=(await pool.query("SELECT value FROM rayeq_settings WHERE key='demo:rayeq-pilot-20261122'")).rows[0]?.value;
 const config=(await pool.query("SELECT value FROM rayeq_settings WHERE key='config'")).rows[0]?.value;
 assert.ok(seed?.seedId==='rayeq-pilot-20261122'&&config?.isDemo&&!config.intakeEnabled&&Date.parse(seed.expiresAt)>Date.now());
 async function tokenFor(id:string){const row=(await pool.query('SELECT * FROM rayeq_users WHERE id=$1 AND email_verified',[id])).rows[0];assert.ok(row);const value=await session(pool,row);tokens.push(value.token);return value.token;}
 const customerRow=(await pool.query('SELECT id,email,role FROM rayeq_users WHERE id=$1',[seed.customerId])).rows[0];assert.equal(customerRow.role,'customer');assert.ok(customerRow.email.endsWith('@rayeq.invalid'));
 const customer=await tokenFor(seed.customerId),worker=await tokenFor(seed.workerUserId),admin=await tokenFor((await pool.query("SELECT id FROM rayeq_users WHERE email='angluosr@gmail.com' AND role='admin'")).rows[0].id);
 async function api(path:string,token?:string,method='GET',data?:any){const response=await fetch(base+path,{method,headers:{'Content-Type':'application/json',...(token?{Authorization:'Bearer '+token}:{})},body:data===undefined?undefined:JSON.stringify(data)});const body=response.status===204?{}:await response.json();return{status:response.status,...body};}
 const candidate=(await pool.query('SELECT id FROM rayeq_bookings WHERE customer_id=$1 AND employee_id=$2 ORDER BY created_at DESC LIMIT 1',[seed.customerId,seed.employeeId])).rows[0];assert.ok(candidate);
 let r=await api('/bookings/'+candidate.id,worker);assert.equal(r.status,200);assert.ok(r.data.customerProfile,'Wait for booking-profile deployment');
 const original=(await api('/profile',customer)).data.bio;let seeded=false;
 if(!original){const result=await pool.query("INSERT INTO rayeq_profiles(user_id,bio) VALUES($1,$2) ON CONFLICT(user_id) DO UPDATE SET bio=$2,updated_at=now() WHERE rayeq_profiles.bio='' RETURNING user_id",[seed.customerId,'حساب عميل تجريبي لعرض الملف الشخصي. هذه نبذة توضيحية وليست بيانات عميل حقيقي.']);seeded=result.rowCount===1;}
 const expected=(await api('/profile',customer)).data.bio;assert.ok(expected);
 const reads:any[]=[];
 for(const [audience,token,path] of [['customer',customer,'/bookings/'+candidate.id],['assigned-worker',worker,'/bookings/'+candidate.id],['admin',admin,'/bookings/'+candidate.id],['worker-list',worker,'/worker/bookings'],['admin-list',admin,'/admin/bookings'],['own-list',customer,'/bookings']]){r=await api(path,token);assert.equal(r.status,200);const item=r.data.items?r.data.items.find((item:any)=>item.id===candidate.id):r.data;assert.equal(item.customerProfile.bio,expected);assert.ok(item.customerProfile.name);reads.push({audience,status:r.status,hasCustomerProfile:true});}
 outsider=randomUUID();await pool.query("INSERT INTO rayeq_users(id,name,email,password_hash,role,email_verified) VALUES($1,'Bio access QA',$2,'!disabled-test!','customer',true)",[outsider,outsider+'@example.test']);const other=await tokenFor(outsider);
 assert.equal((await api('/bookings/'+candidate.id,other)).status,404);assert.equal((await api('/bookings/'+candidate.id)).status,401);
 r=await api('/profile?userId='+seed.customerId,other);assert.equal(r.data.id,outsider);assert.equal(r.data.bio,'');
 const result={checkedAt:new Date().toISOString(),bookingId:candidate.id,reads,otherCustomerStatus:404,anonymousStatus:401,userIdQueryCannotBrowse:true,seededExplicitlyFictionalDemoBio:seeded,customerProfile:{name:(await api('/bookings/'+candidate.id,worker)).data.customerProfile.name,bio:expected}};
 await writeFile('/tmp/rayeq-customer-bio-live.json',JSON.stringify(result,null,2));console.log(JSON.stringify(result,null,2));
}
main().catch(error=>{console.error('BOOKING BIO LIVE',error.message);process.exitCode=1}).finally(async()=>{try{if(tokens.length)await pool.query('DELETE FROM rayeq_sessions WHERE token_hash=ANY($1::text[])',[tokens.map(hash)]);if(outsider){await pool.query('DELETE FROM rayeq_limits WHERE key=$1',[hash('api:'+outsider)]);await pool.query('DELETE FROM rayeq_users WHERE id=$1',[outsider]);}console.log('Temporary bio verification sessions/account removed');}finally{await pool.end()}});
