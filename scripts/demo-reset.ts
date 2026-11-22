import {pool,tx,audit} from '../lib/db';
const seedId='rayeq-pilot-20261122',key='demo:'+seedId;
async function main(){const row=(await pool.query('SELECT value FROM rayeq_settings WHERE key=$1',[key])).rows[0];if(!row){console.log('No matching demo seed remains');return}const m=row.value;
 const ids=(await pool.query("SELECT id FROM rayeq_bookings WHERE document->>'demoSeed'=$1",[seedId])).rows.map(r=>r.id);
 console.log(JSON.stringify({dryRun:!process.argv.includes('--confirm'),seedId,bookings:ids.length,services:m.serviceIds.length,areas:m.areaIds.length,removeTestAccounts:process.argv.includes('--remove-test-accounts')}));
 if(!process.argv.includes('--confirm'))return;
 await tx(async db=>{
  const c=(await db.query("SELECT value FROM rayeq_settings WHERE key='config' FOR UPDATE")).rows[0].value;c.intakeEnabled=false;delete c.demoPilot;
  const others=await db.query("SELECT id FROM rayeq_bookings WHERE document->'service'->>'id'=ANY($1::text[]) AND COALESCE(document->>'demoSeed','')<>$2 LIMIT 1",[m.serviceIds,seedId]);if(others.rowCount)throw Error('Non-demo booking references demo catalog; inspect before wiping');
  await db.query('DELETE FROM rayeq_idempotency WHERE booking_id=ANY($1::uuid[])',[ids]);
  await db.query('DELETE FROM rayeq_bookings WHERE id=ANY($1::uuid[])',[ids]);
  await db.query('UPDATE rayeq_employees SET service_ids=$1,area_ids=$2 WHERE id=$3',[m.previousServiceIds,m.previousAreaIds,m.employeeId]);
  await db.query('DELETE FROM rayeq_services WHERE id=ANY($1::uuid[])',[m.serviceIds]);
  await db.query('DELETE FROM rayeq_areas WHERE id=ANY($1::uuid[])',[m.areaIds]);
  if(process.argv.includes('--remove-test-accounts')){
   if((await db.query('SELECT id FROM rayeq_payroll WHERE employee_id=$1 LIMIT 1',[m.employeeId])).rowCount)throw Error('Payroll exists; inspect before removing test employee');
   if((await db.query('SELECT id FROM rayeq_bookings WHERE customer_id=$1 OR employee_id=$2 LIMIT 1',[m.customerId,m.employeeId])).rowCount)throw Error('Other bookings exist; inspect before removing test users');
   const userIds=[m.customerId,m.workerUserId];
   await db.query('DELETE FROM rayeq_sessions WHERE user_id=ANY($1::uuid[])',[userIds]);
   await db.query('DELETE FROM rayeq_codes WHERE email IN ($1,$2)',['customer-test@rayeq.invalid','worker-test@rayeq.invalid']);
   await db.query('UPDATE rayeq_audit SET actor_id=NULL WHERE actor_id=ANY($1::uuid[])',[userIds]);
   await db.query('DELETE FROM rayeq_employees WHERE id=$1 AND user_id=$2',[m.employeeId,m.workerUserId]);
   await db.query('DELETE FROM rayeq_users WHERE id=ANY($1::uuid[]) AND email IN ($2,$3)',[userIds,'customer-test@rayeq.invalid','worker-test@rayeq.invalid']);
  }
  await db.query("UPDATE rayeq_settings SET value=$1 WHERE key='config'",[JSON.stringify(c)]);
  await db.query('DELETE FROM rayeq_settings WHERE key=$1',[key]);
  const owner=(await db.query("SELECT id FROM rayeq_users WHERE email=$1 AND role='admin'",['angluosr@gmail.com'])).rows[0];if(owner)await audit(db,owner.id,'DEMO_REMOVED',seedId,{removedBookings:ids.length,testAccountsRemoved:process.argv.includes('--remove-test-accounts')});
 });console.log('Demo removed; public intake remains closed. Audit history retained.');}
main().catch(e=>{console.error(e.message);process.exitCode=1}).finally(()=>pool.end());
