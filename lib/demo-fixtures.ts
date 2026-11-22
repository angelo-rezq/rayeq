export const pilotPreview={
 seedId:'rayeq-pilot-20261122',
 customerName:'كريم أحمد',customerNameEn:'Karim Ahmed',
 workerName:'أحمد حسن',workerNameEn:'Ahmed Hassan',
 areaNameAr:'حي النخيل',areaNameEn:'Al Nakheel District',
 contactPhone:'010 •••• 4821',
 address:{street:'شارع الياسمين',streetEn:'Al Yasmeen Street',building:'12',floor:'2',apartment:'4',directions:'المدخل الرئيسي، الدور التاني على اليمين.',directionsEn:'Main entrance, second floor on the right.'},
 services:{
  'd0e00000-0000-4000-8000-000000000001':{nameAr:'حلاقة وتصفيف',nameEn:'Haircut & styling',priceMinor:20000,descriptionAr:'قصة شعر متظبطة ولمسة نهائية على ذوقك.',descriptionEn:'A tailored haircut with a clean finishing touch.',category:'العناية بالشعر',categoryEn:'Hair care'},
  'd0e00000-0000-4000-8000-000000000002':{nameAr:'تهذيب وتحديد الدقن',nameEn:'Beard trim & shape',priceMinor:10000,descriptionAr:'تحديد دقيق وتهذيب يناسب شكل وشك.',descriptionEn:'A precise beard trim shaped to suit your face.',category:'العناية بالدقن',categoryEn:'Beard care'}
 } as Record<string,{nameAr:string,nameEn:string,priceMinor:number,descriptionAr:string,descriptionEn:string,category:string,categoryEn:string}>
};
export function paymentStatusLabels(status:string){
 const labels:Record<string,[string,string]>={UNPAID:['لسه ما اتدفعش','Not paid yet'],PENDING_REVIEW:['قيد المراجعة','Under review'],PAID:['تم الدفع','Paid']};
 const pair=labels[status];return pair?{statusLabelAr:pair[0],statusLabelEn:pair[1]}:{};
}
