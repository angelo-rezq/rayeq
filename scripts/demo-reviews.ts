import {pool,tx} from '../lib/db';
const seedId='rayeq-pilot-20261122',reviewId='d0e00000-0000-4000-8000-000000000501';
async function main(){console.log(await tx(async db=>{
 const m=(await db.query('SELECT value FROM rayeq_settings WHERE key=$1 FOR UPDATE',['demo:'+seedId])).rows[0]?.value,c=(await db.query("SELECT value FROM rayeq_settings WHERE key='config'")).rows[0]?.value;
 if(!m||m.seedId!==seedId||!c?.isDemo||c.intakeEnabled||!c.demoPilot?.enabled||c.demoPilot.seedId!==seedId)throw Error('Closed matching pilot required');
 const b=(await db.query("SELECT * FROM rayeq_bookings WHERE document->>'demoSeed'=$1 AND customer_id=$2 AND employee_id=$3 AND status='COMPLETED' ORDER BY created_at LIMIT 1 FOR UPDATE",[seedId,m.customerId,m.employeeId])).rows[0];if(!b)throw Error('Existing completed demo fixture required');
 const existing=(await db.query('SELECT * FROM rayeq_reviews WHERE booking_id=$1 OR id=$2 FOR UPDATE',[b.id,reviewId])).rows;
 if(existing.length>1||existing.some(r=>r.booking_id!==b.id||r.customer_id!==m.customerId||r.employee_id!==m.employeeId||r.demo_seed!==seedId))throw Error('Review seed identity collision');
 if(!existing.length)await db.query('INSERT INTO rayeq_reviews(id,booking_id,customer_id,employee_id,rating,text,customer_display_name,demo_seed) VALUES($1,$2,$3,$4,5,$5,$6,$7)',[reviewId,b.id,m.customerId,m.employeeId,'تقييم تجريبي لعرض شكل المراجعات، وليس تجربة عميل حقيقية.','عميل تجريبي',seedId]);
 m.reviewIds=existing.length?existing.map(r=>r.id):[reviewId];await db.query('UPDATE rayeq_settings SET value=$1 WHERE key=$2',[JSON.stringify(m),'demo:'+seedId]);return{demoOnly:true,reviews:m.reviewIds.length,created:!existing.length};
}));}
main().catch(e=>{console.error(e.message);process.exitCode=1}).finally(()=>pool.end());
