import {pool,tx,audit} from '../lib/db';
import {pilotPreview as p} from '../lib/demo-fixtures';
async function main(){console.log(await tx(async db=>{
 const m=(await db.query('SELECT value FROM rayeq_settings WHERE key=$1 FOR UPDATE',['demo:'+p.seedId])).rows[0]?.value;
 const config=(await db.query("SELECT value FROM rayeq_settings WHERE key='config' FOR UPDATE")).rows[0]?.value;
 if(!m||m.seedId!==p.seedId||config?.intakeEnabled!==false||config?.isDemo!==true||config?.demoPilot?.seedId!==p.seedId)throw Error('Expected closed allowlisted pilot');
 const users=(await db.query('SELECT id,email,role FROM rayeq_users WHERE id=ANY($1::uuid[]) FOR UPDATE',[[m.customerId,m.workerUserId]])).rows;
 if(!users.some(u=>u.id===m.customerId&&u.email==='customer-test@rayeq.invalid'&&u.role==='customer')||!users.some(u=>u.id===m.workerUserId&&u.email==='worker-test@rayeq.invalid'&&u.role==='worker'))throw Error('Pilot identity mismatch');
 const employee=(await db.query('SELECT id,user_id FROM rayeq_employees WHERE id=$1 FOR UPDATE',[m.employeeId])).rows[0];if(employee?.user_id!==m.workerUserId)throw Error('Pilot employee mismatch');
 const ids=[m.completedBookingId,m.confirmedBookingId];
 if(ids.some(id=>!id))throw Error('Seed booking identifiers missing');
 const bookings=(await db.query('SELECT * FROM rayeq_bookings WHERE id=ANY($1::uuid[]) FOR UPDATE',[ids])).rows;
 if(bookings.length!==2||bookings.some(b=>b.document.demoSeed!==p.seedId||b.customer_id!==m.customerId||b.employee_id!==m.employeeId||!p.services[b.document.service.id]||!m.areaIds.includes(b.document.area.id)||b.document.price.totalMinor!==0||b.document.payment.status!=='UNPAID'||b.document.payment.collectedMinor!==0))throw Error('Unexpected booking ownership or monetary state');
 if(!process.argv.includes('--confirm'))return{dryRun:true,bookings:bookings.length,maskedPhone:true,area:p.areaNameAr};
 for(const id of m.serviceIds){const s=p.services[id];if(!s)throw Error('Unexpected service');await db.query('UPDATE rayeq_services SET name_ar=$2,description_ar=$3,category=$4,version=version+1 WHERE id=$1',[id,s.nameAr,s.descriptionAr,s.category]);}
 await db.query('UPDATE rayeq_areas SET name_ar=$2,version=version+1 WHERE id=ANY($1::uuid[])',[m.areaIds,p.areaNameAr]);
 await db.query('UPDATE rayeq_users SET name=$2 WHERE id=$1',[m.customerId,p.customerName]);
 await db.query('UPDATE rayeq_users SET name=$2 WHERE id=$1',[m.workerUserId,p.workerName]);
 await db.query('UPDATE rayeq_employees SET name=$2 WHERE id=$1',[m.employeeId,p.workerName]);
 for(const b of bookings){const d=b.document,s=p.services[d.service.id];d.service={...d.service,nameAr:s.nameAr,nameEn:s.nameEn};d.area={...d.area,nameAr:p.areaNameAr,nameEn:p.areaNameEn};d.customerName=p.customerName;d.customerNameEn=p.customerNameEn;d.contactPhone=p.contactPhone;d.contactPhoneMasked=true;d.address={...p.address};d.assignedWorker={...d.assignedWorker,nameEn:p.workerNameEn};d.dispatchAllowed=false;
  await db.query('UPDATE rayeq_bookings SET document=$2,version=version+1,updated_at=now() WHERE id=$1',[b.id,JSON.stringify(d)]);
 }
 const admin=(await db.query("SELECT id FROM rayeq_users WHERE email=$1 AND role='admin'",['angluosr@gmail.com'])).rows[0];if(!admin)throw Error('Admin missing');
 await audit(db,admin.id,'DEMO_PRESENTATION_UPDATED',p.seedId,{bookingIds:ids,fictionalData:true,maskedPhone:true,publicIntakeEnabled:false,paymentStatesUnchanged:true});
 return{updated:true,bookings:bookings.length,maskedPhone:true,dispatchAllowed:false,publicIntakeEnabled:false};
}));}
main().catch(e=>{console.error(e.message);process.exitCode=1}).finally(()=>pool.end());
