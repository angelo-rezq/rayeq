import assert from 'node:assert/strict';import {readFile} from 'node:fs/promises';import sharp from 'sharp';
import {pool,tx} from '../lib/db';
import {publicImageStorageBytes} from '../lib/barber-profile-data';
import {encodeWorkPhoto,galleryLimits} from '../lib/gallery-storage';
const seed='rayeq-pilot-20261122';
async function main(){
 const c=(await pool.query("SELECT value FROM rayeq_settings WHERE key='config'")).rows[0]?.value,m=(await pool.query('SELECT value FROM rayeq_settings WHERE key=$1',['demo:'+seed])).rows[0]?.value;assert.ok(c?.isDemo&&!c.intakeEnabled&&c.demoPilot?.enabled&&c.demoPilot.seedId===seed&&Date.parse(c.demoPilot.expiresAt)>Date.now());assert.ok(m?.seedId===seed&&Array.isArray(m.nearbyVirtualEmployeeIds));
 const ids=[m.employeeId,...m.nearbyVirtualEmployeeIds];assert.equal(ids.length,3);const e=(await pool.query('SELECT id,user_id,active FROM rayeq_employees WHERE id=ANY($1::uuid[])',[ids])).rows;assert.equal(e.length,3);assert.ok(e.every(r=>r.active&&(r.id===m.employeeId?r.user_id===m.workerUserId:r.user_id===null)));
 let inserted=0;for(let i=0;i<ids.length;i++){
  const image=i<2?await readFile('rayeq-mobile/assets/images/'+(i===0?'barber-alex.webp':'barber-daniel.webp')):await sharp(Buffer.from('<svg xmlns="http://www.w3.org/2000/svg" width="400" height="500"><rect width="400" height="500" fill="#242326"/><text x="200" y="280" font-family="sans-serif" font-size="150" fill="#d6b45b" text-anchor="middle">Y</text></svg>')).png().toBuffer();
  const encoded=await encodeWorkPhoto(image,i<2?'image/webp':'image/png'),portrait=await sharp(encoded.bytes).resize(512,512,{fit:'inside',withoutEnlargement:true}).webp({quality:82}).toBuffer();
  const r=await tx(async db=>{await db.query("SELECT pg_advisory_xact_lock(hashtextextended('rayeq-gallery-storage',0))");if(await publicImageStorageBytes(db)+portrait.length>galleryLimits.maxStorageBytes)throw Error('Public image storage budget exceeded');return db.query("INSERT INTO rayeq_barber_profiles(employee_id,title_ar,title_en,bio_ar,bio_en,years_experience,specialties_ar,specialties_en,portrait_bytes,portrait_version,demo_seed) VALUES($1,'حلاق تجريبي','Demo barber','ملف نموذجي للعرض فقط. الصورة والخبرة والتخصصات بيانات تجريبية، وليست سيرة مهنية أو خبرة حقيقية لصاحب الصورة.','Demonstration profile only. The stock portrait, experience and specialties are fictional presentation data, not the pictured person’s real work history.',$2,$3,$4,$5,1,$6) ON CONFLICT DO NOTHING RETURNING employee_id",[ids[i],[6,4,3][i],['قص الشعر','تهذيب اللحية'],['Haircuts','Beard grooming'],portrait,seed]);});inserted+=r.rowCount||0;
 }
 console.log(JSON.stringify({demoPublicProfilesInserted:inserted,employeeIds:ids,stockPortraitsClearlyDemo:true,releaseMetadataUnchanged:true}));
}
main().catch(e=>{console.error(e.name,e.message);process.exitCode=1}).finally(()=>pool.end());
