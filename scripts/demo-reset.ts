import {pool,tx,audit} from '../lib/db';
const seedId='rayeq-pilot-20261122',key='demo:'+seedId;
const cleanLaunch=process.argv.includes('--clean-launch');
const removeAccounts=cleanLaunch||process.argv.includes('--remove-test-accounts');
const confirm=process.argv.includes('--confirm');
async function main(){console.log(JSON.stringify(await tx(async db=>{
 const row=(await db.query('SELECT value FROM rayeq_settings WHERE key=$1 FOR UPDATE',[key])).rows[0];
 if(!row)return{dryRun:!confirm,noMatchingDemoSeed:true,nothingDeleted:true};
 const m=row.value;
 if(m.seedId!==seedId||!Array.isArray(m.serviceIds)||!Array.isArray(m.areaIds)||!m.customerId||!m.workerUserId||!m.employeeId)throw Error('Unexpected demo manifest');
 const c=(await db.query("SELECT value FROM rayeq_settings WHERE key='config' FOR UPDATE")).rows[0].value;
 const ids=(await db.query("SELECT id FROM rayeq_bookings WHERE document->>'demoSeed'=$1 FOR UPDATE",[seedId])).rows.map(r=>r.id);
 const others=await db.query("SELECT id FROM rayeq_bookings WHERE (document->'service'->>'id'=ANY($1::text[]) OR document->'area'->>'id'=ANY($2::text[])) AND COALESCE(document->>'demoSeed','')<>$3 LIMIT 1",[m.serviceIds,m.areaIds,seedId]);
 if(others.rowCount)throw Error('Non-demo booking references demo catalog; inspect before wiping');
 const relatedEmployee=await db.query('SELECT id FROM rayeq_employees WHERE id<>$1 AND (service_ids && $2::uuid[] OR area_ids && $3::uuid[]) LIMIT 1',[m.employeeId,m.serviceIds,m.areaIds]);if(relatedEmployee.rowCount)throw Error('Other employees reference demo catalog; inspect before wiping');
 const userIds=[m.customerId,m.workerUserId];
 let employeeCount=0;
 let users:any[]=[];
 if(removeAccounts){
  users=(await db.query('SELECT id,email FROM rayeq_users WHERE id=ANY($1::uuid[]) FOR UPDATE',[userIds])).rows;
  if(users.some(u=>u.id===m.customerId?u.email!=='customer-test@rayeq.invalid':u.email!=='worker-test@rayeq.invalid'))throw Error('Pilot account identity changed; inspect before wiping');
  const employee=(await db.query('SELECT user_id FROM rayeq_employees WHERE id=$1 FOR UPDATE',[m.employeeId])).rows[0];
  employeeCount=employee?1:0;
  if(employee&&employee.user_id!==m.workerUserId)throw Error('Pilot employee identity changed; inspect before wiping');
  if((await db.query('SELECT id FROM rayeq_payroll WHERE employee_id=$1 LIMIT 1',[m.employeeId])).rowCount)throw Error('Payroll exists; inspect before removing pilot employee');
  if((await db.query("SELECT id FROM rayeq_bookings WHERE (customer_id=$1 OR employee_id=$2) AND COALESCE(document->>'demoSeed','')<>$3 LIMIT 1",[m.customerId,m.employeeId,seedId])).rowCount)throw Error('Other bookings exist; inspect before removing pilot accounts');
 }
 const report={dryRun:!confirm,seedId,bookings:ids.length,nearbyPreviews:Array.isArray(m.nearbyBarbers)?m.nearbyBarbers.length:0,services:m.serviceIds.length,areas:m.areaIds.length,removeTestAccounts:removeAccounts,testAccounts:removeAccounts?users.length:0,testEmployees:employeeCount,cleanLaunch,publicIntakeAfter:false,isDemoAfter:cleanLaunch?false:c.isDemo,auditHistoryRetained:true};
 if(!confirm)return report;
 c.intakeEnabled=false;delete c.demoPilot;if(cleanLaunch)c.isDemo=false;
 await db.query('DELETE FROM rayeq_idempotency WHERE booking_id=ANY($1::uuid[])',[ids]);
 await db.query('DELETE FROM rayeq_bookings WHERE id=ANY($1::uuid[])',[ids]);
 await db.query('UPDATE rayeq_employees SET service_ids=$1,area_ids=$2 WHERE id=$3',[m.previousServiceIds,m.previousAreaIds,m.employeeId]);
 await db.query('DELETE FROM rayeq_services WHERE id=ANY($1::uuid[])',[m.serviceIds]);
 await db.query('DELETE FROM rayeq_areas WHERE id=ANY($1::uuid[])',[m.areaIds]);
 if(removeAccounts){
  await db.query('DELETE FROM rayeq_sessions WHERE user_id=ANY($1::uuid[])',[userIds]);
  await db.query('DELETE FROM rayeq_codes WHERE email IN ($1,$2)',['customer-test@rayeq.invalid','worker-test@rayeq.invalid']);
  await db.query('UPDATE rayeq_audit SET actor_id=NULL WHERE actor_id=ANY($1::uuid[])',[userIds]);
  await db.query('DELETE FROM rayeq_employees WHERE id=$1 AND user_id=$2',[m.employeeId,m.workerUserId]);
  await db.query('DELETE FROM rayeq_users WHERE id=ANY($1::uuid[]) AND email IN ($2,$3)',[userIds,'customer-test@rayeq.invalid','worker-test@rayeq.invalid']);
 }
 await db.query("UPDATE rayeq_settings SET value=$1 WHERE key='config'",[JSON.stringify(c)]);
 await db.query('DELETE FROM rayeq_settings WHERE key=$1',[key]);
 const owner=(await db.query("SELECT id FROM rayeq_users WHERE email=$1 AND role='admin'",['angluosr@gmail.com'])).rows[0];
 if(owner)await audit(db,owner.id,'DEMO_REMOVED',seedId,{removedBookings:ids.length,testAccountsRemoved:removeAccounts,cleanLaunch});
 return{...report,removed:true};
})));}
main().catch(e=>{console.error(e.message);process.exitCode=1}).finally(()=>pool.end());
