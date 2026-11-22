import assert from 'node:assert/strict';
import {randomUUID} from 'node:crypto';
import sharp from 'sharp';
import {pool,migrate} from '../lib/db';
import {handle} from '../lib/api';
import {session,hash} from '../lib/auth';
const ids:string[]=[],tokens:string[]=[];let passed=0;
function check(v:unknown,label:string){assert.ok(v,label);passed++;console.log('PASS',label)}
async function request(path:string,method='GET',data?:any,token?:string,mime='application/json'){
 const req=new Request('https://rayeq-platform.onrender.com/api/v1'+path,{method,headers:{'Content-Type':mime,...(token?{Authorization:'Bearer '+token}:{})},body:data===undefined?undefined:(data instanceof Uint8Array?new Uint8Array(data).buffer:JSON.stringify(data))});const r=process.env.RAYEQ_LIVE_TEST==='1'?await fetch(req):await handle(req,path.split('?')[0].split('/').filter(Boolean));
 const type=r.headers.get('Content-Type')||'';return {status:r.status,data:type.includes('application/json')?await r.json():new Uint8Array(await r.arrayBuffer()),type};
}
async function run(){await migrate();
 for(let i=0;i<2;i++){const id=randomUUID();ids.push(id);await pool.query("INSERT INTO rayeq_users(id,name,email,password_hash,role,email_verified) VALUES($1,$2,$3,'!disabled-test!','customer',true)",[id,'ملف اختبار مؤقت','profile-test-'+id+'@rayeq.invalid']);const row=(await pool.query('SELECT * FROM rayeq_users WHERE id=$1',[id])).rows[0];tokens.push((await session(pool,row)).token)}
 let r=await request('/profile');check(r.status===401,'anonymous profile denied');
 r=await request('/profile','GET',undefined,tokens[0]);check(r.status===200&&r.data.data.id===ids[0]&&r.data.data.avatarUrl===null&&r.data.data.bio==='','self profile fields returned');
 r=await request('/profile','PATCH',{name:'اسم تجربة محدث',phone:'+201000000000'},tokens[0]);check(r.status===200&&r.data.data.name==='اسم تجربة محدث'&&r.data.data.phone==='+201000000000','own name and contact phone persist');check(r.data.data.emailVerified&&r.data.data.role==='customer','contact phone does not change identity or role');
 r=await request('/profile','PATCH',{role:'admin'},tokens[0]);check(r.status===400,'role update rejected');
 r=await request('/profile','PATCH',{email:'other@rayeq.invalid'},tokens[0]);check(r.status===400,'email update rejected');
 r=await request('/profile','PATCH',{userId:ids[1],name:'other'},tokens[0]);check(r.status===400,'cross-user update target rejected');
 r=await request('/profile','PATCH',{phone:'bad-number'},tokens[0]);check(r.status===400,'invalid contact phone rejected');
 r=await request('/profile','PATCH',{},tokens[0]);check(r.status===400,'empty update rejected');
 r=await request('/profile?userId='+ids[0],'GET',undefined,tokens[1]);check(r.status===200&&r.data.data.id===ids[1]&&r.data.data.phone==='','query cannot select another profile');
 r=await request('/profile','PATCH',{bio:'  نبذة شخصية خاصة  '},tokens[0]);check(r.status===200&&r.data.data.bio==='نبذة شخصية خاصة','own private bio saved and trimmed');
 r=await request('/profile?userId='+ids[0],'GET',undefined,tokens[1]);check(r.status===200&&r.data.data.id===ids[1]&&r.data.data.bio==='','private bio cannot be read by another account query');
 for(const bio of [null,{},['invalid'],'x'.repeat(1501)])check((await request('/profile','PATCH',{bio},tokens[0])).status===400,'invalid private bio rejected');
 r=await request('/profile','PATCH',{bio:'ن'.repeat(1500)},tokens[0]);check(r.status===200&&r.data.data.bio.length===1500,'maximum length Arabic bio accepted');
 r=await request('/profile','PATCH',{bio:''},tokens[0]);check(r.status===200&&r.data.data.bio==='','empty private bio clears');
 r=await request('/profile','PATCH',{bio:'Private fixture'},tokens[0]);check(r.status===200&&r.data.data.name==='اسم تجربة محدث'&&r.data.data.phone==='+201000000000','bio-only update preserves name and phone');
 r=await request('/profile/avatar','GET',undefined,tokens[0]);check(r.status===404,'missing avatar is explicit 404');
 r=await request('/profile/avatar','PUT',new TextEncoder().encode('<svg/>'),tokens[0],'image/svg+xml');check(r.status===415,'SVG rejected');
 r=await request('/profile/avatar','PUT',new Uint8Array(2*1024*1024+1),tokens[0],'image/png');check(r.status===413,'oversized streamed upload rejected');
 r=await request('/profile/avatar','PUT',new TextEncoder().encode('not an image'),tokens[0],'image/png');check(r.status===400,'invalid image bytes rejected');
 const png=await sharp({create:{width:1200,height:700,channels:3,background:'#c49a70'}}).png().toBuffer();
 r=await request('/profile/avatar','PUT',png,tokens[0],'image/jpeg');check(r.status===400,'MIME and decoded format must agree');
 r=await request('/profile/avatar','PUT',png,tokens[0],'image/png');check(r.status===200&&r.data.data.avatarUrl?.includes('/profile/avatar?v=1'),'valid image saved and private versioned URL returned');
 r=await request('/profile/avatar','GET',undefined,tokens[0]);const meta=await sharp(r.data).metadata();check(r.status===200&&r.type==='image/webp'&&meta.format==='webp'&&meta.width!<=512&&meta.height!<=512,'avatar normalized to bounded WebP');
 r=await request('/profile/avatar?userId='+ids[0],'GET',undefined,tokens[1]);check(r.status===404,'another account cannot read avatar by query');
 r=await request('/profile/avatar','GET');check(r.status===401,'anonymous avatar denied');
 r=await request('/profile/avatar','DELETE',undefined,tokens[0]);check(r.status===204,'avatar deletion succeeds');
 r=await request('/profile/avatar','GET',undefined,tokens[0]);check(r.status===404,'deleted avatar no longer served');
 console.log('RESULT',passed,'profile/image checks passed');
}
run().catch(e=>{console.error('FAILED',e.message);process.exitCode=1}).finally(async()=>{if(ids.length){await pool.query('DELETE FROM rayeq_audit WHERE actor_id=ANY($1::uuid[])',[ids]);await pool.query('DELETE FROM rayeq_sessions WHERE user_id=ANY($1::uuid[])',[ids]);await pool.query('DELETE FROM rayeq_users WHERE id=ANY($1::uuid[])',[ids]);await pool.query('DELETE FROM rayeq_limits WHERE key=ANY($1::text[])',[ids.flatMap(id=>[hash('avatar:'+id),hash('api:'+id)])]);}await pool.end()});
