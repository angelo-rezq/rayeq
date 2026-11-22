export type Service = {id:string;name:string;description:string;duration:number;price:number;category:string};
// Demonstration catalog only. Not approved commercial prices.
export const demoServices: Service[] = [
 {id:'hair',name:'قص وتصفيف الشعر',description:'قصة تناسبك، وتشطيب على مزاجك.',duration:45,price:180,category:'الشعر'},
 {id:'beard',name:'تهذيب وتحديد الذقن',description:'تفاصيل مرتبة، وإطلالة متجددة.',duration:25,price:100,category:'الذقن'},
 {id:'complete',name:'العناية الكاملة',description:'قص شعر وتحديد ذقن في زيارة واحدة.',duration:70,price:250,category:'باقات'},
];
