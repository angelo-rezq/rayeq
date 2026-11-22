import {pool,DB} from './db';
// No setting means OFF. Never applies once email is configured or real intake opens.
export async function emailVerificationBypass(db:DB=pool){
 const {rows}=await db.query("SELECT key,value FROM rayeq_settings WHERE key IN ('auth:emailVerificationBypass','config')");
 const setting=rows.find(r=>r.key==='auth:emailVerificationBypass')?.value;
 const config=rows.find(r=>r.key==='config')?.value;
 const expiresAt=typeof setting?.expiresAt==='string'?setting.expiresAt:null;
 const emailConfigured=Boolean((process.env.MAILJET_API_KEY&&process.env.MAILJET_SECRET_KEY&&process.env.MAIL_FROM)||(process.env.SMTP_HOST&&process.env.SMTP_FROM));
 const enabled=setting?.enabled===true&&!emailConfigured&&config?.intakeEnabled===false&&!!expiresAt&&Number.isFinite(Date.parse(expiresAt))&&Date.parse(expiresAt)>Date.now();
 return{enabled,expiresAt:enabled?expiresAt:null,maxAccounts:100,emailConfigured};
}
