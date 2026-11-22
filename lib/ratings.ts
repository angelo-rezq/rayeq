import {DB} from './db';
export function publicReview(r:any){return{id:r.id,rating:r.rating,text:r.text,customerDisplayName:r.customer_display_name,createdAt:r.created_at,demoOnly:Boolean(r.demo_seed)}}
export async function ratingSummaryMany(db:DB,ids:string[],demoSeed?:string){
 const out:Record<string,{ratingAverage:number|null,reviewCount:number}>={};for(const id of ids)out[id]={ratingAverage:null,reviewCount:0};
 if(!ids.length)return out;
 const rows=(await db.query('SELECT employee_id,round(avg(rating)::numeric,2)::float8 average,count(*)::int count FROM rayeq_reviews WHERE employee_id=ANY($1::uuid[]) AND NOT hidden AND (demo_seed IS NULL OR demo_seed=$2) GROUP BY employee_id',[ids,demoSeed||null])).rows;
 for(const r of rows)out[r.employee_id]={ratingAverage:r.average,reviewCount:r.count};return out;
}
export function bookingReviewState(row:any,u:{id:string,role:string}){const own=u.role==='customer'&&row.customer_id===u.id;return{canReview:Boolean(own&&row.status==='COMPLETED'&&row.employee_id&&!row.review_json),review:own&&row.review_json?publicReview(row.review_json):null}}
