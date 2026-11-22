import {pool,tx} from '../lib/db';
import {pilotPreview as p} from '../lib/demo-fixtures';
async function main(){console.log(await tx(async db=>{
 const m=(await db.query('SELECT value FROM rayeq_settings WHERE key=$1 FOR UPDATE',['demo:'+p.seedId])).rows[0]?.value;if(!m||m.seedId!==p.seedId)throw Error('Pilot manifest missing');
 const services=(await db.query('SELECT * FROM rayeq_services WHERE id=ANY($1::uuid[]) FOR UPDATE',[m.serviceIds])).rows;
 const areas=(await db.query('SELECT * FROM rayeq_areas WHERE id=ANY($1::uuid[]) FOR UPDATE',[m.areaIds])).rows;
 if(services.length!==2||areas.length!==1||services.some(s=>!p.services[s.id]||s.name_ar!==p.services[s.id].nameAr)||areas.some(a=>a.name_ar!==p.areaNameAr))throw Error('Unexpected fixture names; inspect before translating');
 if(!process.argv.includes('--confirm'))return{dryRun:true,services:services.length,areas:areas.length,pricesUnchanged:true};
 let changed=0;
 for(const s of services){const item=p.services[s.id];if(s.name_en&&s.description_en&&s.category_en)continue;await db.query("UPDATE rayeq_services SET name_en=CASE WHEN name_en='' THEN $2 ELSE name_en END,description_en=CASE WHEN description_en='' THEN $3 ELSE description_en END,category_en=CASE WHEN category_en='' THEN $4 ELSE category_en END,version=version+1 WHERE id=$1",[s.id,item.nameEn,item.descriptionEn,item.categoryEn]);changed++;}
 for(const a of areas)if(!a.name_en){await db.query('UPDATE rayeq_areas SET name_en=$2,version=version+1 WHERE id=$1',[a.id,p.areaNameEn]);changed++;}
 return{updated:true,changed,pricesUnchanged:true};
}));}
main().catch(error=>{console.error(error.message);process.exitCode=1}).finally(()=>pool.end());
