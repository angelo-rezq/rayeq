'use client';
import {FormEvent,ReactNode} from 'react';
type Value=Record<string,any>;
function Field({label,children}:{label:string;children:ReactNode}){return <label>{label}{children}</label>}
type Props={value:Value;busy:boolean;onSave:(data:Value)=>Promise<void>;onError:(message:string)=>void};
export function CatalogServiceForm({value,busy,onSave,onError}:Props){
 async function submit(event:FormEvent<HTMLFormElement>){event.preventDefault();const f=new FormData(event.currentTarget);const active=f.get('active')==='on';const nameEn=String(f.get('nameEn')||'').trim(),descriptionEn=String(f.get('descriptionEn')||'').trim(),categoryEn=String(f.get('categoryEn')||'').trim(),descriptionAr=String(f.get('description')||'').trim();
  if(active&&(!nameEn||!categoryEn||(descriptionAr&&!descriptionEn))){onError('أكمل اسم الخدمة والفئة والوصف بالإنجليزي قبل إتاحتها للعملاء. يمكنك حفظها موقوفة لحين إكمال الترجمة.');return;}
  await onSave({nameAr:String(f.get('name')||'').trim(),nameEn,descriptionAr,descriptionEn,category:String(f.get('category')||'').trim(),categoryEn,durationMinutes:Number(f.get('duration')),priceMinor:Math.round(Number(f.get('price'))*100),active,...(value.version?{version:value.version}:{})});
 }
 return <form onSubmit={submit}>
  <p>اكتب النص العربي والإنجليزي بشكل مستقل. النص الإنجليزي يظهر في النسخة الإنجليزية من التطبيق.</p>
  <div className="form-row"><Field label="اسم الخدمة بالعربي"><input name="name" required maxLength={150} defaultValue={value.nameAr}/></Field><Field label="اسم الخدمة بالإنجليزي"><input name="nameEn" dir="ltr" maxLength={150} defaultValue={value.nameEn||''}/></Field></div>
  <div className="form-row"><Field label="وصف الخدمة بالعربي"><textarea name="description" maxLength={1000} defaultValue={value.descriptionAr}/></Field><Field label="وصف الخدمة بالإنجليزي"><textarea name="descriptionEn" dir="ltr" maxLength={1000} defaultValue={value.descriptionEn||''}/></Field></div>
  <div className="form-row"><Field label="الفئة بالعربي"><input name="category" required maxLength={100} defaultValue={value.category}/></Field><Field label="الفئة بالإنجليزي"><input name="categoryEn" dir="ltr" maxLength={100} defaultValue={value.categoryEn||''}/></Field></div>
  <div className="form-row"><Field label="المدة بالدقائق"><input name="duration" type="number" min="5" max="480" required defaultValue={value.durationMinutes}/></Field><Field label="السعر بالجنيه"><input name="price" type="number" min="0" max="100000" step="0.01" required defaultValue={value.priceMinor/100}/></Field></div>
  <label className="dash-checkbox"><input name="active" type="checkbox" defaultChecked={value.active}/> الخدمة متاحة للعملاء</label>
  <button className="primary full" disabled={busy}>حفظ الخدمة</button>
 </form>;
}
export function CatalogAreaForm({value,busy,onSave,onError}:Props){
 async function submit(event:FormEvent<HTMLFormElement>){event.preventDefault();const f=new FormData(event.currentTarget);const active=f.get('active')==='on',nameEn=String(f.get('nameEn')||'').trim();if(active&&!nameEn){onError('أكمل اسم المنطقة بالإنجليزي قبل إتاحتها للعملاء، أو احفظها موقوفة.');return;}await onSave({nameAr:String(f.get('name')||'').trim(),nameEn,travelFeeMinor:Math.round(Number(f.get('fee'))*100),active,...(value.version?{version:value.version}:{})});}
 return <form onSubmit={submit}>
  <div className="form-row"><Field label="اسم المنطقة بالعربي"><input name="name" required maxLength={150} defaultValue={value.nameAr}/></Field><Field label="اسم المنطقة بالإنجليزي"><input name="nameEn" dir="ltr" maxLength={150} defaultValue={value.nameEn||''}/></Field></div>
  <Field label="رسوم الانتقال بالجنيه"><input name="fee" type="number" min="0" max="100000" step="0.01" required defaultValue={value.travelFeeMinor/100}/></Field>
  <label className="dash-checkbox"><input name="active" type="checkbox" defaultChecked={value.active}/> المنطقة متاحة للعملاء</label><button className="primary full" disabled={busy}>حفظ المنطقة</button>
 </form>;
}
