import {pool,tx,audit} from '../lib/db';
import {pilotPreview as p} from '../lib/demo-fixtures';
async function main(){console.log(JSON.stringify(await tx(async db=>{
 const m=(await db.query('SELECT value FROM rayeq_settings WHERE key=$1 FOR UPDATE',['demo:'+p.seedId])).rows[0]?.value;
 const c=(await db.query("SELECT value FROM rayeq_settings WHERE key='config' FOR UPDATE")).rows[0]?.value;
 if(!m||m.seedId!==p.seedId||!m.confirmedBookingId||c?.isDemo!==true||c?.intakeEnabled!==false||c?.demoPilot?.enabled!==true||c?.demoPilot?.seedId!==p.seedId)throw Error('Expected closed allowlisted preview');
 const b=(await db.query('SELECT * FROM rayeq_bookings WHERE id=$1 FOR UPDATE',[m.confirmedBookingId])).rows[0];
 if(!b||b.reference!=='RY-261122-0A109FE0'||b.customer_id!==m.customerId||b.employee_id!==m.employeeId||b.status!=='CONFIRMED'||b.document.demoSeed!==p.seedId||b.document.payment.status!=='UNPAID'||b.document.payment.collectedMinor!==0||!m.serviceIds.includes(b.document.service.id)||!m.areaIds.includes(b.document.area.id))throw Error('Unexpected demo booking or payment state');
 const expected=p.services[b.document.service.id]?.priceMinor;if(expected!==20000)throw Error('Expected approved haircut preview amount');
 const services=(await db.query('SELECT id,price_minor FROM rayeq_services WHERE id=ANY($1::uuid[]) FOR UPDATE',[m.serviceIds])).rows;
 const areas=(await db.query('SELECT id,travel_fee_minor FROM rayeq_areas WHERE id=ANY($1::uuid[]) FOR UPDATE',[m.areaIds])).rows;
 if(services.length!==2||areas.length!==1||services.some(s=>!p.services[s.id]||![0,p.services[s.id].priceMinor].includes(s.price_minor))||areas.some(a=>a.travel_fee_minor!==0)||![0,expected].includes(b.document.price.totalMinor))throw Error('Unexpected catalog/booking price; inspect before replacing it');
 const before=structuredClone(b.document.price),after={...before,serviceMinor:expected,travelMinor:0,discountMinor:0,totalMinor:expected};
 const report={dryRun:!process.argv.includes('--confirm'),reference:b.reference,before,after,services:services.map(s=>({id:s.id,beforeMinor:s.price_minor,afterMinor:p.services[s.id].priceMinor})),paymentStatus:b.document.payment.status,collectedMinor:b.document.payment.collectedMinor,bookingStatus:b.status,fictionalPreviewOnly:true,realIntakeEnabled:false};
 if(!process.argv.includes('--confirm'))return report;
 for(const s of services)if(s.price_minor!==p.services[s.id].priceMinor)await db.query('UPDATE rayeq_services SET price_minor=$2,version=version+1 WHERE id=$1',[s.id,p.services[s.id].priceMinor]);
 if(JSON.stringify(before)!==JSON.stringify(after)){const doc=b.document;doc.price=after;doc.dispatchAllowed=false;doc.previewPricing=true;await db.query('UPDATE rayeq_bookings SET document=$2,version=version+1,updated_at=now() WHERE id=$1',[b.id,JSON.stringify(doc)]);}
 const admin=(await db.query("SELECT id FROM rayeq_users WHERE email=$1 AND role='admin'",['angluosr@gmail.com'])).rows[0];if(!admin)throw Error('Admin missing');
 await audit(db,admin.id,'DEMO_PREVIEW_PRICES_UPDATED',p.seedId,{reference:b.reference,before,after,fictionalPreviewOnly:true,paymentStateUnchanged:true});
 return{...report,updated:true};
})));}
main().catch(error=>{console.error(error.message);process.exitCode=1}).finally(()=>pool.end());
