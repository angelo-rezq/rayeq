import {DB} from './db';
import {pilotNearbyBarbers,pilotPreview} from './demo-fixtures';
export async function prepareNearbyDemo(db:DB,m:any){
 const barbers=pilotNearbyBarbers(m.employeeId,m.serviceIds,m.areaIds),virtual=barbers.filter(b=>b.id!==m.employeeId);
 for(const b of virtual){const previous=(await db.query('SELECT * FROM rayeq_employees WHERE id=$1 FOR UPDATE',[b.id])).rows[0];
  if(previous){if(!m.nearbyVirtualEmployeeIds?.includes(b.id)||previous.user_id!==null||previous.name!==b.nameAr||previous.name_en!==b.nameEn||previous.phone!==''||previous.salary_minor!==0)throw Error('Preview employee identity changed; inspect before seeding');}
  else await db.query("INSERT INTO rayeq_employees(id,name,name_en,phone,active,service_ids,area_ids,salary_minor) VALUES($1,$2,$3,'',true,$4,$5,0)",[b.id,b.nameAr,b.nameEn,m.serviceIds,m.areaIds]);
 }
 await db.query("UPDATE rayeq_employees SET name_en=$2 WHERE id=$1 AND user_id=$3 AND name=$4 AND name_en=''",[m.employeeId,pilotPreview.workerNameEn,m.workerUserId,pilotPreview.workerName]);
 return{...m,nearbyBarbers:barbers,nearbyVirtualEmployeeIds:virtual.map(b=>b.id),nearbySeededAt:new Date().toISOString()};
}
