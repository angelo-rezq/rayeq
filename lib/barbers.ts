import {ratingSummaryMany} from './ratings';
import {z} from 'zod';
import {DB,pool,tx,audit} from './db';
import {User,fail,mailReady} from './auth';
const uuid=z.string().uuid();
export const pointSchema=z.object({latitude:z.number().finite().min(-90).max(90),longitude:z.number().finite().min(-180).max(180)}).strict();
export const nearbySchema=z.object({latitude:z.number().finite().min(-90).max(90).optional(),longitude:z.number().finite().min(-180).max(180).optional(),serviceId:uuid,areaId:uuid.optional(),requestedAt:z.string().datetime({offset:true}).optional()}).strict().refine(p=>(p.latitude===undefined)===(p.longitude===undefined),'Coordinates must be supplied together').refine(p=>p.latitude!==undefined||Boolean(p.areaId),'Location or area is required');
export type Nearby=z.infer<typeof nearbySchema>;
export type DemoDirectory={seedId:string,expiresAt:string,asOf?:string,pilotEmployeeId:string,pilotWorkerUserId:string,virtualEmployeeIds:string[],barbers:DemoBarber[]};
export type DemoBarber={id:string,nameAr:string,nameEn:string,coarseZoneLat:number,coarseZoneLon:number,serviceIds:string[],areaIds:string[]};
const FRESH_MINUTES=15,ZONE_HOURS=24,RADIUS_KM=20;
export function coarse(value:number){return Math.round(value*100)/100;}
function distance(a:number,b:number,c:number,d:number){const rad=Math.PI/180,x=Math.sin((c-a)*rad/2)**2+Math.cos(a*rad)*Math.cos(c*rad)*Math.sin((d-b)*rad/2)**2;return 6371*2*Math.atan2(Math.sqrt(Math.min(1,x)),Math.sqrt(Math.max(0,1-x)));}
export function distanceBand(km:number){const lower=Math.floor(km/2)*2;return{minKm:lower,maxKm:lower+2};}
export async function demoDirectory(db:DB,c:any,u:User):Promise<DemoDirectory|undefined>{
 if(c.intakeEnabled&&(mailReady()||process.env.RAYEQ_TEST_MODE==='1'))return;
 if(!(c.isDemo&&c.demoPilot?.enabled&&c.demoPilot.customerIds?.includes(u.id)&&Date.parse(c.demoPilot.expiresAt)>Date.now()))return;
 const m=(await db.query('SELECT value FROM rayeq_settings WHERE key=$1',['demo:'+c.demoPilot.seedId])).rows[0]?.value;
 if(!m||m.seedId!==c.demoPilot.seedId||!Array.isArray(m.nearbyBarbers))return;
 return{seedId:m.seedId,expiresAt:c.demoPilot.expiresAt,asOf:m.nearbySeededAt||m.createdAt,pilotEmployeeId:m.employeeId,pilotWorkerUserId:m.workerUserId,virtualEmployeeIds:m.nearbyVirtualEmployeeIds||[],barbers:m.nearbyBarbers};
}
export async function nearby(db:DB,p:Nearby,demo?:DemoDirectory){
 const now=new Date(),requested=p.requestedAt?new Date(p.requestedAt):now;
 if(p.requestedAt&&(requested.getTime()<now.getTime()-60000||requested.getTime()>now.getTime()+60*86400000))fail(400,'INVALID_SCHEDULE','اختر موعداً خلال الستين يوماً القادمة');
 const service=(await db.query('SELECT duration_minutes FROM rayeq_services WHERE id=$1 AND active',[p.serviceId])).rows[0];if(!service)fail(400,'SERVICE_UNAVAILABLE','الخدمة غير متاحة');
 if(p.areaId&&!(await db.query('SELECT id FROM rayeq_areas WHERE id=$1 AND active',[p.areaId])).rowCount)fail(400,'AREA_UNAVAILABLE','المنطقة غير متاحة');
 const end=new Date(requested.getTime()+(service.duration_minutes+15)*60000);
 let rows:any[];
 if(demo){
  const eligible=(await db.query("SELECT e.id FROM rayeq_employees e LEFT JOIN rayeq_users u ON u.id=e.user_id WHERE e.active AND e.id=ANY($1::uuid[]) AND $2::uuid=ANY(e.service_ids) AND ($3::uuid IS NULL OR $3::uuid=ANY(e.area_ids)) AND ((e.id=$4 AND e.user_id=$5 AND u.role='worker' AND u.email_verified) OR (e.id=ANY($6::uuid[]) AND e.user_id IS NULL)) AND NOT EXISTS(SELECT 1 FROM rayeq_bookings b WHERE b.employee_id=e.id AND b.status NOT IN ('CANCELLED','COMPLETED') AND ((b.start_at<$8 AND b.end_at>$7) OR (b.status IN ('ON_THE_WAY','ARRIVED','IN_PROGRESS') AND $7::timestamptz<=$9::timestamptz+interval '15 minutes')))",[demo.barbers.map(b=>b.id),p.serviceId,p.areaId||null,demo.pilotEmployeeId,demo.pilotWorkerUserId,demo.virtualEmployeeIds,requested.toISOString(),end.toISOString(),now.toISOString()])).rows.map(r=>r.id);
  rows=demo.barbers.filter(b=>eligible.includes(b.id)&&b.serviceIds.includes(p.serviceId)&&(!p.areaId||b.areaIds.includes(p.areaId))).map(b=>({...b,id:b.id,name:b.nameAr,name_en:b.nameEn,coarse_zone_lat:b.coarseZoneLat,coarse_zone_lon:b.coarseZoneLon,availability_updated_at:demo.asOf||now,location_updated_at:demo.asOf||now,demo_preview:true}));
 }
 else rows=(await db.query("SELECT e.id,e.name,e.name_en,e.coarse_zone_lat,e.coarse_zone_lon,e.availability_updated_at,e.location_updated_at FROM rayeq_employees e JOIN rayeq_users u ON u.id=e.user_id WHERE e.active AND u.role='worker' AND u.email_verified AND e.availability_status='available' AND e.availability_updated_at>=$3::timestamptz-interval '15 minutes' AND $1::uuid=ANY(e.service_ids) AND ($2::uuid IS NULL OR $2::uuid=ANY(e.area_ids)) AND NOT EXISTS(SELECT 1 FROM rayeq_bookings b WHERE b.employee_id=e.id AND b.status NOT IN ('CANCELLED','COMPLETED') AND ((b.start_at<$5 AND b.end_at>$4) OR (b.status IN ('ON_THE_WAY','ARRIVED','IN_PROGRESS') AND $4::timestamptz<=$3::timestamptz+interval '15 minutes')))",[p.serviceId,p.areaId||null,now.toISOString(),requested.toISOString(),end.toISOString()])).rows;
 const located=p.latitude!==undefined;
 const items=rows.map(r=>{const hasZone=r.coarse_zone_lat!==null&&r.coarse_zone_lon!==null&&r.coarse_zone_lat!==undefined&&r.coarse_zone_lon!==undefined&&(r.demo_preview||new Date(r.location_updated_at).getTime()>=now.getTime()-ZONE_HOURS*3600000);const km=located&&hasZone?distance(coarse(p.latitude!),coarse(p.longitude!),Number(r.coarse_zone_lat),Number(r.coarse_zone_lon)):null;return{r,km,hasZone};}).filter(x=>!located||(x.hasZone&&x.km!==null&&x.km<=RADIUS_KM)).sort((a,b)=>(a.km??0)-(b.km??0)||a.r.name.localeCompare(b.r.name));
 const ratings=await ratingSummaryMany(db,items.slice(0,30).map(({r})=>r.id),demo?.seedId);
 return{mode:located?'location':'area',barbers:items.slice(0,30).map(({r,km})=>({id:r.id,nameAr:r.name,nameEn:r.name_en||'',...ratings[r.id],demoOnly:Boolean(demo),availabilityStatus:'available',availabilityUpdatedAt:new Date(r.availability_updated_at).toISOString(),approximateDistance:km===null?null:distanceBand(km)})),checkedAt:now.toISOString(),requestedAt:requested.toISOString(),availabilityFreshForMinutes:FRESH_MINUTES,locationMaxAgeHours:ZONE_HOURS,radiusKm:located?RADIUS_KM:null,selectionIsReservation:false,...(demo?{demoOnly:true,availabilityIsPreview:true}:{}),...(!items.length?{emptyReason:'NO_AVAILABLE_BARBERS',canUseAreaFallback:located}:{} )};
}
export async function recheckBarber(db:DB,p:{preferredBarberId:string,serviceId:string,areaId:string,requestedAt?:string,customerLocation?:{latitude:number,longitude:number}},demo?:DemoDirectory){
 await db.query('SELECT id FROM rayeq_employees WHERE id=$1 FOR UPDATE',[p.preferredBarberId]);
 const result=await nearby(db,{serviceId:p.serviceId,areaId:p.areaId,requestedAt:p.requestedAt,...p.customerLocation},demo);
 const barber=result.barbers.find(b=>b.id===p.preferredBarberId);if(!barber)fail(409,'BARBER_UNAVAILABLE','الحلاق لم يعد متاحاً لهذا الطلب، حدّث القائمة أو أكمل بدون اختيار حلاق');
 return{id:barber.id,nameAr:barber.nameAr,nameEn:barber.nameEn,availabilityCheckedAt:result.checkedAt};
}
export async function availabilityRoute(req:Request,path:string,u:User,readBody:<T>(req:Request,schema:z.ZodType<T>)=>Promise<T>){
 if(path!=='/worker/availability'||!['GET','PATCH'].includes(req.method))return;
 if(u.role!=='worker')fail(403,'WORKER_ONLY','هذه الخطوة للعامل المفعّل فقط');
 if(req.method==='PATCH'){
  const p=await readBody(req,z.object({availabilityStatus:z.enum(['offline','available','busy']),location:pointSchema.nullable().optional()}).strict());
  await tx(async db=>{const e=(await db.query('SELECT * FROM rayeq_employees WHERE user_id=$1 AND active FOR UPDATE',[u.id])).rows[0];if(!e)fail(403,'WORKER_NOT_ACTIVE','حساب العامل غير مفعّل');
   await db.query('UPDATE rayeq_employees SET availability_status=$2,availability_updated_at=now(),coarse_zone_lat=$3,coarse_zone_lon=$4,location_updated_at=$5 WHERE id=$1',[e.id,p.availabilityStatus,p.location===null?null:p.location?coarse(p.location.latitude):e.coarse_zone_lat,p.location===null?null:p.location?coarse(p.location.longitude):e.coarse_zone_lon,p.location===null?null:p.location?new Date():e.location_updated_at]);
   await audit(db,u.id,'worker.availability',e.id,{availabilityStatus:p.availabilityStatus,hasCoarseZone:p.location!==null&&Boolean(p.location||e.coarse_zone_lat!==null)});
  });
 }
 const e=(await pool.query('SELECT availability_status,availability_updated_at,location_updated_at,coarse_zone_lat FROM rayeq_employees WHERE user_id=$1 AND active',[u.id])).rows[0];if(!e)fail(403,'WORKER_NOT_ACTIVE','حساب العامل غير مفعّل');
 const isFresh=e.availability_updated_at!==null&&new Date(e.availability_updated_at).getTime()>=Date.now()-FRESH_MINUTES*60000;
 return Response.json({data:{availabilityStatus:e.availability_status,isFresh,effectiveAvailabilityStatus:isFresh?e.availability_status:'offline',availabilityUpdatedAt:e.availability_updated_at,locationUpdatedAt:e.location_updated_at,hasCoarseZone:e.coarse_zone_lat!==null,freshForMinutes:FRESH_MINUTES}});
}
