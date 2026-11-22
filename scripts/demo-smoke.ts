import {pilotPreview} from '../lib/demo-fixtures';
import {randomUUID} from 'node:crypto';
import {DateTime} from 'luxon';
import {pool,tx} from '../lib/db';
import {session,hash} from '../lib/auth';
const base='https://rayeq-platform.onrender.com/api/v1',key='demo:rayeq-pilot-20261122';
async function main(){
 const manifest=(await pool.query('SELECT value FROM rayeq_settings WHERE key=$1',[key])).rows[0]?.value;if(!manifest)throw Error('SEED_MISSING');
 const rows=(await pool.query('SELECT * FROM rayeq_users WHERE email=ANY($1::text[])',[['angluosr@gmail.com','customer-test@rayeq.invalid','worker-test@rayeq.invalid']])).rows;
 const tokens:Record<string,string>={};let blockedId='';
 try{
  for(const[email,role]of [['angluosr@gmail.com','admin'],['customer-test@rayeq.invalid','customer'],['worker-test@rayeq.invalid','worker']]){
   const r=rows.find(r=>r.email===email&&r.role===role&&r.email_verified);if(!r)throw Error('ROLE_MISMATCH');tokens[role]=(await session(pool,r)).token;
  }
  async function api(role:string,path:string,method='GET',body?:any,idempotencyKey?:string,expected=200){
   const r=await fetch(base+path,{method,headers:{'Content-Type':'application/json',Authorization:'Bearer '+tokens[role],...(idempotencyKey?{'Idempotency-Key':idempotencyKey}:{})},body:body===undefined?undefined:JSON.stringify(body)});
   const d=await r.json();if(r.status!==expected)throw Error(path+' expected '+expected+' got '+r.status+' '+d.error?.code);return d.data;
  }
  const catalog=await(await fetch(base+'/catalog')).json();if(!catalog.data.demoOnly||!catalog.data.intakeEnabled||!catalog.data.isDemo)throw Error('DEMO_DEPLOY_NOT_LIVE');
  const q=await api('customer','/quotes','POST',{serviceId:manifest.serviceIds[0],areaId:manifest.areaIds[0]});if(q.totalMinor!==pilotPreview.services[q.serviceId]?.priceMinor)throw Error('PREVIEW_PRICE_MISMATCH');
  let plan=manifest.e2ePlan;
  if(!plan){
   const now=DateTime.now().setZone('Africa/Cairo');plan={};
   for(const[name,hours]of [['completed',1],['confirmed',3]]as const){const t=now.plus({hours}).startOf('minute');plan[name]={idempotencyKey:randomUUID(),payload:{serviceId:q.serviceId,areaId:q.areaId,serviceVersion:q.serviceVersion,areaVersion:q.areaVersion,customerName:'تجربة فقط - لا توجد زيارة حقيقية',contactPhone:'0000000000',locationType:'home',address:{street:'عنوان تجريبي - لا ترسل عاملاً',building:'تجربة',floor:'0',apartment:'0',directions:'اختبار التطبيق فقط. لا خدمة ولا تحصيل.'},bookingType:'scheduled',localDate:t.toFormat('yyyy-MM-dd'),localTime:t.toFormat('HH:mm'),timezone:'Africa/Cairo',paymentMethod:'cash',consent:true},startAt:t.toUTC().toISO()}}
   await pool.query("UPDATE rayeq_settings SET value=jsonb_set(value,'{e2ePlan}',$2::jsonb) WHERE key=$1",[key,JSON.stringify(plan)]);
  }
  blockedId=randomUUID();await pool.query("INSERT INTO rayeq_users(id,name,email,password_hash,role,email_verified) VALUES($1,$2,$3,'!disabled-test!','customer',true)",[blockedId,'Temporary demo access test','blocked-demo-'+blockedId+'@rayeq.invalid']);
  tokens.blocked=(await session(pool,{id:blockedId,name:'Temporary test',email:'blocked-demo@rayeq.invalid',role:'customer',email_verified:true})).token;
  await api('blocked','/bookings','POST',plan.completed.payload,randomUUID(),503);
  await api('customer','/bookings','POST',{...plan.completed.payload,serviceId:randomUUID()},randomUUID(),400);
  console.log('Demo allowlist and seeded-catalog restriction verified');
  for(const name of ['completed','confirmed']){
   const p=plan[name];const response=await fetch(base+'/bookings',{method:'POST',headers:{'Content-Type':'application/json',Authorization:'Bearer '+tokens.customer,'Idempotency-Key':p.idempotencyKey},body:JSON.stringify(p.payload)});const data=await response.json();if(![200,201].includes(response.status))throw Error('CREATE_FAILED_'+data.error?.code);let b=data.data;
   if(b.status==='PENDING'||b.status==='UNDER_REVIEW'){
    b=await api('admin','/admin/bookings/'+b.id+'/assign','POST',{employeeId:manifest.employeeId,startAt:p.startAt,version:b.version});
   }
   if(b.status==='ASSIGNED')b=await api('admin','/admin/bookings/'+b.id+'/status','PATCH',{status:'CONFIRMED',version:b.version});
   if(name==='completed')for(const next of ['ON_THE_WAY','ARRIVED','IN_PROGRESS','COMPLETED']){
    const order=['CONFIRMED','ON_THE_WAY','ARRIVED','IN_PROGRESS','COMPLETED'];if(order.indexOf(b.status)>=order.indexOf(next))continue;
    b=await api('worker','/worker/bookings/'+b.id+'/status','PATCH',{status:next,version:b.version});
   }
   const visible=await api('customer','/bookings/'+b.id);const workerList=await api('worker','/worker/bookings?limit=100');if(!workerList.items.some((r:any)=>r.id===b.id)||visible.status!==b.status||b.payment.status!=='UNPAID'||![0,pilotPreview.services[b.service.id].priceMinor].includes(b.price.totalMinor))throw Error('FLOW_CHECK_FAILED');
   await pool.query("UPDATE rayeq_settings SET value=jsonb_set(value,$2::text[],$3::jsonb) WHERE key=$1",[key,[name+'BookingId'],JSON.stringify(b.id)]);
   console.log(JSON.stringify({scenario:name,bookingId:b.id,reference:b.reference,status:b.status,customerVisible:true,workerVisible:true,totalMinor:b.price.totalMinor,paymentStatus:b.payment.status}));
  }
 }finally{
  for(const token of Object.values(tokens))await pool.query('DELETE FROM rayeq_sessions WHERE token_hash=$1',[hash(token)]);
  if(blockedId){await pool.query('DELETE FROM rayeq_sessions WHERE user_id=$1',[blockedId]);await pool.query('DELETE FROM rayeq_users WHERE id=$1',[blockedId]);}
 }
}
main().catch(e=>{console.error(e.message);process.exitCode=1}).finally(()=>pool.end());
