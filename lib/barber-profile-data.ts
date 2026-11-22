import {DB} from './db';
const origin=()=>String(process.env.PUBLIC_ORIGIN||process.env.RENDER_EXTERNAL_URL||'').replace(/\/$/,'');
export async function publicImageStorageBytes(db:DB){return Number((await db.query('SELECT (SELECT COALESCE(sum(byte_size),0) FROM rayeq_work_photos)+(SELECT COALESCE(sum(octet_length(portrait_bytes)),0) FROM rayeq_barber_profiles) AS bytes')).rows[0].bytes)}
export async function publicBarberMediaMany(db:DB,ids:string[],demoSeed?:string){
 if(!ids.length)return {} as Record<string,{portraitUrl:string|null,galleryThumbnailUrl:string|null}>;
 const rows=(await db.query('SELECT e.id,p.portrait_version,octet_length(p.portrait_bytes) portrait_size,(SELECT w.id FROM rayeq_work_photos w WHERE w.employee_id=e.id AND (w.demo_seed IS NULL OR w.demo_seed=$2) ORDER BY w.created_at DESC,w.id DESC LIMIT 1) gallery_id FROM rayeq_employees e LEFT JOIN rayeq_barber_profiles p ON p.employee_id=e.id WHERE e.id=ANY($1::uuid[])',[ids,demoSeed||null])).rows;
 return Object.fromEntries(rows.map(r=>[r.id,{portraitUrl:r.portrait_size?origin()+'/api/v1/barber-portraits/'+r.id+'?v='+r.portrait_version:null,galleryThumbnailUrl:r.gallery_id?origin()+'/api/v1/work-photos/'+r.gallery_id:null}])) as Record<string,{portraitUrl:string|null,galleryThumbnailUrl:string|null}>;
}
export async function publicBarberFields(db:DB,id:string){
 const r=(await db.query('SELECT e.id,e.service_ids,e.area_ids,p.title_ar,p.title_en,p.bio_ar,p.bio_en,p.years_experience,p.specialties_ar,p.specialties_en,p.portrait_version,octet_length(p.portrait_bytes) portrait_size FROM rayeq_employees e LEFT JOIN rayeq_barber_profiles p ON p.employee_id=e.id WHERE e.id=$1',[id])).rows[0];
 if(!r)return {};
 const services=(await db.query('SELECT id,name_ar,name_en,description_ar,description_en,price_minor,duration_minutes FROM rayeq_services WHERE id=ANY($1::uuid[]) AND active ORDER BY name_ar',[r.service_ids])).rows.map(s=>({id:s.id,nameAr:s.name_ar,nameEn:s.name_en||'',descriptionAr:s.description_ar,descriptionEn:s.description_en||'',priceMinor:s.price_minor,durationMinutes:s.duration_minutes,currency:'EGP',priceExcludesTravel:true}));
 const areas=(await db.query('SELECT id,name_ar,name_en FROM rayeq_areas WHERE id=ANY($1::uuid[]) AND active ORDER BY name_ar',[r.area_ids])).rows.map(a=>({id:a.id,nameAr:a.name_ar,nameEn:a.name_en||''}));
 return {titleAr:r.title_ar||'',titleEn:r.title_en||'',bioAr:r.bio_ar||'',bioEn:r.bio_en||'',yearsExperience:r.years_experience??null,specialtiesAr:r.specialties_ar||[],specialtiesEn:r.specialties_en||[],portraitUrl:r.portrait_size?origin()+'/api/v1/barber-portraits/'+id+'?v='+r.portrait_version:null,areaNameAr:areas.map(a=>a.nameAr).filter(Boolean).join('، '),areaNameEn:areas.map(a=>a.nameEn).filter(Boolean).join(', '),serviceAreas:areas,services,startingPriceMinor:services.length?Math.min(...services.map(s=>s.priceMinor)):null,currency:'EGP',priceExcludesTravel:true};
}
