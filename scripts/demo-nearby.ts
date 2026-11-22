import {pool,tx} from '../lib/db';
import {pilotPreview} from '../lib/demo-fixtures';
import {prepareNearbyDemo} from '../lib/demo-nearby';
async function main(){console.log(await tx(async db=>{
 const key='demo:'+pilotPreview.seedId;let m=(await db.query('SELECT value FROM rayeq_settings WHERE key=$1 FOR UPDATE',[key])).rows[0]?.value;
 const c=(await db.query("SELECT value FROM rayeq_settings WHERE key='config'")).rows[0]?.value;
 if(!m||m.seedId!==pilotPreview.seedId||!m.employeeId||!c?.isDemo||c?.demoPilot?.seedId!==m.seedId)throw Error('Active pilot manifest required');
 if(!process.argv.includes('--confirm'))return{dryRun:true,fictionalBarbers:3,additionalAccounts:0,fictionalEmployeeRecords:2,existingExpiryPreserved:true};
 m=await prepareNearbyDemo(db,m);
 await db.query('UPDATE rayeq_settings SET value=$2 WHERE key=$1',[key,JSON.stringify(m)]);
 return{updated:true,fictionalBarbers:m.nearbyBarbers.length,additionalAccounts:0,fictionalEmployeeRecords:2,expiresAt:m.expiresAt};
}));}
main().catch(e=>{console.error(e.message);process.exitCode=1}).finally(()=>pool.end());
