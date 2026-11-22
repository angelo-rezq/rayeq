import {pool,tx,audit} from '../lib/db';
const seedId='rayeq-pilot-20261122';
const areaLabel='منطقة تجريبية - بدون زيارة حقيقية';
const serviceLabels:Record<string,string>={
 'd0e00000-0000-4000-8000-000000000001':'خدمة تجريبية مجانية: قص شعر',
 'd0e00000-0000-4000-8000-000000000002':'خدمة تجريبية مجانية: تهذيب ذقن'
};
async function main(){console.log(await tx(async db=>{
 const manifest=(await db.query('SELECT value FROM rayeq_settings WHERE key=$1 FOR UPDATE',['demo:'+seedId])).rows[0]?.value;
 if(!manifest||manifest.seedId!==seedId||manifest.areaIds.length!==1||manifest.areaIds[0]!=='d0e00000-0000-4000-8000-000000000101'||manifest.serviceIds.length!==2||!manifest.serviceIds.every((id:string)=>serviceLabels[id]))throw Error('Unexpected demo manifest');
 const areas=(await db.query('SELECT id,name_ar FROM rayeq_areas WHERE id=ANY($1::uuid[]) FOR UPDATE',[manifest.areaIds])).rows;
 const services=(await db.query('SELECT id,name_ar FROM rayeq_services WHERE id=ANY($1::uuid[]) FOR UPDATE',[manifest.serviceIds])).rows;
 const bookings=(await db.query("SELECT id,document FROM rayeq_bookings WHERE document->>'demoSeed'=$1 FOR UPDATE",[seedId])).rows;
 if(areas.length!==1||services.length!==2)throw Error('Demo catalog missing');
 for(const b of bookings)if(!serviceLabels[b.document.service.id]||!manifest.areaIds.includes(b.document.area.id))throw Error('Unexpected booking catalog');
 if(!process.argv.includes('--confirm'))return{dryRun:true,areas:areas.length,services:services.length,bookings:bookings.length,areaLabel,serviceLabels};
 let changed=0;
 for(const a of areas)if(a.name_ar!==areaLabel){await db.query('UPDATE rayeq_areas SET name_ar=$2,version=version+1 WHERE id=$1',[a.id,areaLabel]);changed++;}
 for(const s of services)if(s.name_ar!==serviceLabels[s.id]){await db.query('UPDATE rayeq_services SET name_ar=$2,version=version+1 WHERE id=$1',[s.id,serviceLabels[s.id]]);changed++;}
 for(const b of bookings){const d=b.document;if(d.area.nameAr===areaLabel&&d.service.nameAr===serviceLabels[d.service.id])continue;d.area.nameAr=areaLabel;d.service.nameAr=serviceLabels[d.service.id];await db.query('UPDATE rayeq_bookings SET document=$2,version=version+1,updated_at=now() WHERE id=$1',[b.id,JSON.stringify(d)]);changed++;}
 if(changed){const admin=(await db.query("SELECT id FROM rayeq_users WHERE role='admin' AND email=$1",['angluosr@gmail.com'])).rows[0];if(!admin)throw Error('Admin missing');await audit(db,admin.id,'DEMO_LABELS_NEUTRALIZED',seedId,{changed,areaLabel,serviceLabels});}
 return{updated:true,changed,bookings:bookings.length,areaLabel,serviceLabels};
}));}
main().catch(e=>{console.error(e.message);process.exitCode=1}).finally(()=>pool.end());
