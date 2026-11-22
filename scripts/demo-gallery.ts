import {readFile} from 'node:fs/promises';import {pool,tx} from '../lib/db';import {encodeWorkPhoto,storeWorkPhoto} from '../lib/gallery-storage';
const seedId='rayeq-pilot-20261122';
async function main(){
 const m=(await pool.query('SELECT value FROM rayeq_settings WHERE key=$1',['demo:'+seedId])).rows[0]?.value,c=(await pool.query("SELECT value FROM rayeq_settings WHERE key='config'")).rows[0]?.value,owner=(await pool.query("SELECT id FROM rayeq_users WHERE email='angluosr@gmail.com' AND role='admin' AND email_verified")).rows[0];
 if(!m||m.seedId!==seedId||!c?.isDemo||c.intakeEnabled||!c.demoPilot?.enabled||c.demoPilot.seedId!==seedId||!(Date.parse(c.demoPilot.expiresAt)>Date.now())||!owner)throw Error('Verified closed pilot required');
 const employeeIds=[m.employeeId,...(m.nearbyVirtualEmployeeIds||[])];if(employeeIds.length!==3)throw Error('Expected three guarded preview employees');const photos=[];
 for(let i=0;i<3;i++){
  const id='d0e00000-0000-4000-8000-00000000060'+(i+1),eid=employeeIds[i],prior=(await pool.query('SELECT id,employee_id,demo_seed FROM rayeq_work_photos WHERE id=$1',[id])).rows[0];if(prior){if(prior.employee_id!==eid||prior.demo_seed!==seedId)throw Error('Gallery seed identity collision');continue;}
  const source=['service-hair.webp','service-beard.webp','service-ritual.webp'][i],photo=await encodeWorkPhoto(await readFile('public/mobile-demo/assets/assets/images/'+source),'image/webp');photos.push(await storeWorkPhoto(owner.id,eid,photo,seedId,undefined,id));
 }
 await tx(async db=>{const current=(await db.query('SELECT value FROM rayeq_settings WHERE key=$1 FOR UPDATE',['demo:'+seedId])).rows[0]?.value;if(!current||current.seedId!==seedId)throw Error('Pilot manifest changed');current.galleryIds=(await db.query('SELECT id FROM rayeq_work_photos WHERE demo_seed=$1 AND employee_id=ANY($2::uuid[])',[seedId,employeeIds])).rows.map(r=>r.id);current.gallerySeededAt=current.gallerySeededAt||new Date().toISOString();await db.query('UPDATE rayeq_settings SET value=$1 WHERE key=$2',[JSON.stringify(current),'demo:'+seedId]);});console.log({demoOnly:true,created:photos.length,photos});
}
main().catch(e=>{console.error(e.message);process.exitCode=1}).finally(()=>pool.end());
