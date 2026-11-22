import {Pool} from 'pg';
import {randomBytes} from 'node:crypto';
import {spawnSync} from 'node:child_process';
const suites=process.argv.slice(2);if(!suites.length||suites.some(s=>!['catalog-test','permission-test','profile-test','nearby-test','reviews-test','gallery-test','barber-profile-test','auth-bypass-test','operations-test'].includes(s)))throw Error('Select known test suites');
const uri=new URL(process.env.DATABASE_URL!);uri.hostname=uri.hostname.replace('-pooler.','.');
const admin=new Pool({connectionString:uri.toString(),max:1,ssl:uri.hostname.endsWith('.neon.tech')?{rejectUnauthorized:true}:undefined});
async function main(){
 for(const suite of suites){const schema='qa_catalog_'+randomBytes(8).toString('hex');
 await admin.query('CREATE SCHEMA '+schema);
 try{const scoped=new URL(uri);scoped.searchParams.set('options','-c search_path='+schema);const result=spawnSync(process.execPath,['--import','tsx','scripts/'+suite+'.ts'],{cwd:process.cwd(),env:{...process.env,DATABASE_URL:scoped.toString(),RAYEQ_ISOLATED_TEST:'1',RAYEQ_TEST_MODE:'1'},stdio:'inherit'});if(result.error||result.status!==0)throw Error('Suite failed: '+suite);}
 finally{await admin.query('DROP SCHEMA '+schema+' CASCADE');console.log('Removed isolated schema for',suite);}
 }
}
main().catch(error=>{console.error(error.message);process.exitCode=1}).finally(()=>admin.end());
