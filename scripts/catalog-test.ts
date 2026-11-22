import assert from 'node:assert/strict';
import {randomUUID} from 'node:crypto';
import {pool,migrate} from '../lib/db';
import {handle} from '../lib/api';
import {session} from '../lib/auth';
process.env.RAYEQ_TEST_MODE='1';
let passed=0;
function check(value:any,label:string){assert.ok(value,label);passed++;console.log('PASS',label);}
async function run(){
 const scope=(await pool.query('SELECT current_schema() schema')).rows[0].schema;
 if(process.env.RAYEQ_ISOLATED_TEST!=='1'||!/^qa_catalog_[a-f0-9]+$/.test(scope))throw Error('Catalog checks require their isolated test schema');
 await migrate();
 const tokens:Record<string,string>={};for(const role of ['admin','customer']){const id=randomUUID();await pool.query("INSERT INTO rayeq_users(id,name,email,password_hash,role,email_verified) VALUES($1,$2,$3,'!disabled-test!',$4,true)",[id,'QA fixture','qa-'+id+'@example.test',role]);const u=(await pool.query('SELECT * FROM rayeq_users WHERE id=$1',[id])).rows[0];tokens[role]=(await session(pool,u)).token;}
 async function api(path:string,method='GET',body?:any,role='admin',key?:string){const r=await handle(new Request('http://localhost/api/v1'+path,{method,headers:{'Content-Type':'application/json',...(tokens[role]?{Authorization:'Bearer '+tokens[role]}:{}),...(key?{'Idempotency-Key':key}:{})},body:body===undefined?undefined:JSON.stringify(body)}),path.split('?')[0].slice(1).split('/'));return{status:r.status,...await r.json()};}
 const ar={nameAr:'خدمة جودة',descriptionAr:'وصف الخدمة',category:'الشعر',durationMinutes:30,priceMinor:20000,active:true};
 check((await api('/admin/services','POST',ar,'customer')).status===403,'customer cannot edit catalog');
 check((await api('/admin/catalog','GET',undefined,'anonymous')).status===401,'anonymous cannot inspect admin catalog');
 let r=await api('/admin/services','POST',ar);check(r.status===201&&r.data.nameEn===''&&!r.data.englishReady,'legacy service create remains valid');
 r=await api('/admin/services','POST',{...ar,nameEn:'  Haircut  ',descriptionEn:'  A clean cut. ',categoryEn:' Hair care ',imageUrl:'https://example.test/photo.webp'});check(r.status===201,'bilingual service created');let s=r.data;
 check(s.nameAr===ar.nameAr&&s.nameEn==='Haircut'&&s.descriptionEn==='A clean cut.'&&s.categoryEn==='Hair care'&&s.englishReady,'English fields trim and round-trip separately');
 r=await api('/admin/services/'+s.id,'PATCH',{...ar,version:s.version});check(r.status===200&&r.data.nameEn==='Haircut'&&r.data.imageUrl==='https://example.test/photo.webp','omitted English/image fields preserved on old-client PATCH');s=r.data;
 const stale=await api('/admin/services/'+s.id,'PATCH',{...ar,nameEn:'Wrong stale value',version:s.version-1});check(stale.status===409&&stale.error.code==='VERSION_CONFLICT','stale catalog writes rejected');
 for(const bad of [{nameEn:'x'.repeat(151)},{descriptionEn:'x'.repeat(1001)},{categoryEn:'x'.repeat(101)},{unknownEnglish:'x'}])check((await api('/admin/services','POST',{...ar,...bad})).status===400,'invalid/unknown English service field rejected');
 r=await api('/admin/services/'+s.id,'PATCH',{...ar,nameEn:null,descriptionEn:'',categoryEn:null,imageUrl:null,version:s.version});check(r.status===200&&r.data.nameEn===''&&!r.data.englishReady&&r.data.imageUrl===null,'explicit null/empty English clears without Arabic fallback');s=r.data;
 r=await api('/admin/services/'+s.id,'PATCH',{...ar,nameEn:'Haircut',descriptionEn:'A clean cut.',categoryEn:'Hair care',version:s.version});s=r.data;check(s.englishReady,'service translation readiness restored');
 const areaAr={nameAr:'منطقة الجودة',travelFeeMinor:2500,active:true};r=await api('/admin/areas','POST',{...areaAr,nameEn:' Quality District '});check(r.status===201&&r.data.nameEn==='Quality District'&&r.data.englishReady,'bilingual area create/trim');let a=r.data;
 r=await api('/admin/areas/'+a.id,'PATCH',{...areaAr,version:a.version});check(r.status===200&&r.data.nameEn==='Quality District','old-client area PATCH preserves English');a=r.data;
 check((await api('/admin/areas','POST',{...areaAr,nameEn:'x'.repeat(151)})).status===400,'overlong English area rejected');
 r=await api('/admin/areas/'+a.id,'PATCH',{...areaAr,nameEn:null,version:a.version});check(r.status===200&&!r.data.englishReady&&r.data.nameEn==='','English area can explicitly clear');a=r.data;
 r=await api('/admin/areas/'+a.id,'PATCH',{...areaAr,nameEn:'Quality District',version:a.version});a=r.data;
 r=await api('/catalog','GET',undefined,'anonymous');check(r.status===200&&r.data.services.find((x:any)=>x.id===s.id)?.nameEn==='Haircut'&&r.data.areas.find((x:any)=>x.id===a.id)?.nameEn==='Quality District','public catalog exposes bilingual fields');
 const q=await api('/quotes','POST',{serviceId:s.id,areaId:a.id},'customer');check(q.status===200&&q.data.serviceNameEn==='Haircut'&&q.data.areaNameEn==='Quality District'&&q.data.totalMinor===22500,'quote includes English names and existing price arithmetic');
 await pool.query("UPDATE rayeq_settings SET value=value||'{\"intakeEnabled\":true}'::jsonb WHERE key='config'");
 const payload={serviceId:s.id,areaId:a.id,serviceVersion:s.version,areaVersion:a.version,customerName:'QA customer',contactPhone:'0000000000',locationType:'home',address:{street:'QA street',building:'1'},bookingType:'immediate',timezone:'Africa/Cairo',paymentMethod:'cash',consent:true};
 const booking=await api('/bookings','POST',payload,'customer',randomUUID());check(booking.status===201&&booking.data.service.nameEn==='Haircut'&&booking.data.area.nameEn==='Quality District','new booking snapshots English service/area');
 r=await api('/admin/services/'+s.id,'PATCH',{...ar,nameEn:'Updated haircut',descriptionEn:'Updated copy',categoryEn:'Hair care',priceMinor:25000,version:s.version});s=r.data;
 r=await api('/bookings/'+booking.data.id,'GET',undefined,'customer');check(r.data.service.nameEn==='Haircut'&&r.data.price.totalMinor===22500,'catalog edits do not rewrite booked names/prices');
 r=await api('/admin/services/'+s.id,'PATCH',{...ar,active:false,version:s.version});check(r.status===200,'service can still be hidden');
 r=await api('/catalog','GET',undefined,'anonymous');check(!r.data.services.some((x:any)=>x.id===s.id),'inactive service excluded from public catalog');
 r=await api('/admin/catalog');check(r.data.services.some((x:any)=>x.id===s.id&&!x.active),'inactive service remains in admin history');
 console.log('RESULT',passed,'bilingual catalog checks passed');
}
run().catch(error=>{console.error('CATALOG TEST FAILED',error.name,error.message);process.exitCode=1}).finally(()=>pool.end());
