import assert from 'node:assert/strict';
import {pool} from '../lib/db';
import {session,hash} from '../lib/auth';
const base='https://rayeq-platform.onrender.com/api/v1',tokens:string[]=[];
async function main(){
 const m=(await pool.query("SELECT value FROM rayeq_settings WHERE key='demo:rayeq-pilot-20261122'")).rows[0]?.value;if(!m)throw Error('Pilot manifest missing');
 async function actor(id:string,email:string){const row=(await pool.query('SELECT * FROM rayeq_users WHERE id=$1 AND email=$2 AND email_verified',[id,email])).rows[0];assert.ok(row,'Expected pilot identity');const s=await session(pool,row);tokens.push(s.token);return s.token;}
 const customer=await actor(m.customerId,'customer-test@rayeq.invalid'),worker=await actor(m.workerUserId,'worker-test@rayeq.invalid');
 async function api(path:string,token:string,data?:any){const r=await fetch(base+path,{method:data?'POST':'GET',headers:{Authorization:'Bearer '+token,...(data?{'Content-Type':'application/json'}:{})},body:data?JSON.stringify(data):undefined});const json=await r.json();if(!r.ok)throw Error('Live '+path+' status '+r.status+' '+json.error?.code);return json.data;}
 const workerMe=await api('/me',worker);assert.equal(workerMe.displayNameEn,'Ahmed Hassan');
 const profile=await api('/profile',worker);assert.equal(profile.workerProfile.employeeNameEn,'Ahmed Hassan');
 const now=new Date(),from=new Date(now.getTime()-86400000).toISOString().slice(0,10),to=new Date(now.getTime()+7*86400000).toISOString().slice(0,10);const schedule=await api('/worker/schedule?from='+from+'&to='+to,worker);assert.ok(schedule.items.length);assert.ok(schedule.items.every((i:any)=>i.areaNameEn&&i.serviceNameEn));
 const availability=await api('/worker/availability',worker);assert.equal(availability.availabilityStatus,'offline');
 const catalog=await (await fetch(base+'/catalog')).json();assert.ok(catalog.data.services.every((s:any)=>s.englishReady));
 const input={serviceId:m.serviceIds[0],areaId:m.areaIds[0],latitude:28.0870967,longitude:30.7618397};const nearby=await api('/barbers/nearby',customer,input);assert.equal(nearby.barbers.length,3);assert.equal(nearby.demoOnly,true);assert.equal(nearby.selectionIsReservation,false);assert.ok(!/latitude|longitude|coarseZone|coarse_zone|email|phone|salary|address/.test(JSON.stringify(nearby)));
 const area=await api('/barbers/nearby',customer,{serviceId:m.serviceIds[0],areaId:m.areaIds[0]});assert.ok(area.barbers.every((b:any)=>b.approximateDistance===null));
 const config=(await pool.query("SELECT value FROM rayeq_settings WHERE key='config'")).rows[0].value;assert.equal(config.intakeEnabled,false);
 const fixtures=(await pool.query("SELECT status,document->'payment' payment FROM rayeq_bookings WHERE document->>'demoSeed'=$1",[m.seedId])).rows;assert.ok(fixtures.every(x=>x.payment.status==='UNPAID'&&x.payment.collectedMinor===0));
 console.log(JSON.stringify({verifiedLive:true,workerDisplayNameEn:workerMe.displayNameEn,scheduleEnglishItems:schedule.items.length,workerAvailability:availability.availabilityStatus,nearbyPreview:nearby,areaFallbackCount:area.barbers.length,intakeEnabled:config.intakeEnabled,fixturePaymentsUnchanged:true},null,2));
}
main().catch(e=>{console.error(e.message);process.exitCode=1}).finally(async()=>{if(tokens.length)await pool.query('DELETE FROM rayeq_sessions WHERE token_hash=ANY($1::text[])',[tokens.map(hash)]);await pool.end();console.log('Ephemeral QA sessions revoked');});
