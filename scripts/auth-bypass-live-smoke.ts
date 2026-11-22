import assert from 'node:assert/strict';import {pool} from '../lib/db';
const base='https://rayeq-platform.onrender.com/api/v1',stamp=Date.now(),emails=[`rayeq-test-c-${stamp}@example.invalid`,`rayeq-test-w-${stamp}@example.invalid`],pw=`Tmp-${stamp}-Aa1x`;
async function api(path:string,method='GET',body?:any,token?:string){const r=await fetch(base+path,{method,headers:{'Content-Type':'application/json',...(token?{Authorization:'Bearer '+token}:{})},body:body===undefined?undefined:JSON.stringify(body),signal:AbortSignal.timeout(60000)});return{status:r.status,...(r.status===204?{}:await r.json())}}
async function main(){
 const key='auth:emailVerificationBypass',expiresAt='2026-11-29T14:42:01.872Z';
 try{
 await pool.query("INSERT INTO rayeq_settings(key,value) VALUES($1,$2) ON CONFLICT(key) DO UPDATE SET value=$2",[key,JSON.stringify({enabled:true,expiresAt})]);
 let h=await api('/health');assert.equal(h.data.emailVerificationBypassActive,true);
 const out:any={health:h.data};
 for(const [i,type] of ['customer','worker'].entries()){
  const r=await api('/auth/register','POST',{name:'Rayeq temporary test',email:emails[i],password:pw,accountType:type});assert.equal(r.status,202);assert.equal(r.data.next,'login');assert.ok(!r.data.token);
  const l=await api('/auth/login','POST',{email:emails[i],password:pw});assert.equal(l.status,200);assert.equal(l.data.user.emailVerified,false);assert.equal(l.data.user.role,type==='worker'?'worker_pending':'customer');
  assert.equal((await api('/auth/login','POST',{email:emails[i],password:'wrong-password-123'})).status,401);
  assert.equal((await api('/me','GET',undefined,l.data.token)).status,200);
  out[type]={register:r.status,next:r.data.next,login:l.status,role:l.data.user.role,emailVerified:l.data.user.emailVerified};
  if(type==='customer'){const b=await api('/bookings','POST',{},l.data.token);out.customerRealBookingStatus=b.status;}
 }
 const cfg=(await pool.query("SELECT value->>'intakeEnabled' v FROM rayeq_settings WHERE key='config'")).rows[0].v;assert.equal(cfg,'false');out.realIntake=cfg;
 console.log(JSON.stringify(out,null,1));
 }finally{
  const ids=(await pool.query('SELECT id FROM rayeq_users WHERE email=ANY($1)',[emails])).rows.map(r=>r.id);
  if(ids.length){await pool.query('DELETE FROM rayeq_sessions WHERE user_id=ANY($1::uuid[])',[ids]);await pool.query('DELETE FROM rayeq_audit WHERE actor_id=ANY($1::uuid[])',[ids]);await pool.query('DELETE FROM rayeq_profiles WHERE user_id=ANY($1::uuid[])',[ids]);await pool.query('DELETE FROM rayeq_users WHERE id=ANY($1::uuid[])',[ids]);}
  await pool.query('DELETE FROM rayeq_codes WHERE email=ANY($1)',[emails]);
  console.log('throwaway accounts removed',ids.length,'remaining',(await pool.query('SELECT count(*)::int n FROM rayeq_users WHERE email=ANY($1)',[emails])).rows[0].n);
  console.log('switch left enabled until',expiresAt);
  await pool.end();
 }}
main().catch(e=>{console.error('LIVE FAIL',e.message);process.exitCode=1});
