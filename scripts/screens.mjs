import { chromium } from 'playwright';
import {spawn} from 'node:child_process';
const server=spawn(process.execPath,['node_modules/next/dist/bin/next','start','--port','3100'],{stdio:['ignore','pipe','pipe']});
let log='';server.stdout.on('data',d=>log+=d);server.stderr.on('data',d=>log+=d);
const browser=await chromium.launch({executablePath:'/usr/bin/google-chrome-stable',headless:true,args:['--no-sandbox']});
try{
 const page=await browser.newPage({viewport:{width:390,height:1000},deviceScaleFactor:2});
 for(let i=0;i<50;i++){try{await page.goto('http://localhost:3100');break}catch{await new Promise(r=>setTimeout(r,150))}}
 await page.evaluate(()=>document.fonts.ready); await page.addStyleTag({content:'.bottom-nav{position:static;margin-top:30px}.customer-shell{padding-bottom:0}'});
 await page.screenshot({path:'/downloads/minya-home.png',fullPage:true});
 await page.getByRole('button',{name:'الخدمات',exact:true}).click();await page.screenshot({path:'/downloads/minya-services.png',fullPage:true});
 await page.getByRole('button',{name:'اختيار قص وتصفيف الشعر',exact:true}).click();await page.screenshot({path:'/downloads/minya-booking.png',fullPage:true});
 await page.getByRole('button',{name:'اختار المعاد',exact:true}).click();await page.screenshot({path:'/downloads/minya-schedule.png',fullPage:true});
 for(const width of [320,390,1280]){await page.setViewportSize({width,height:1000});console.log('layout',width,await page.evaluate(()=>({viewport:innerWidth,content:document.documentElement.scrollWidth})));}
 await page.setViewportSize({width:1440,height:1000});await page.goto('http://localhost:3100/design/admin');await page.evaluate(()=>document.fonts.ready); await page.addStyleTag({content:'.bottom-nav{position:static;margin-top:30px}.customer-shell{padding-bottom:0}'});await page.screenshot({path:'/downloads/minya-admin.png',fullPage:true});
 await page.getByRole('button',{name:'الخدمات والأسعار',exact:true}).click();await page.screenshot({path:'/downloads/minya-admin-services.png',fullPage:true});
 console.log('screens complete');
}finally{await browser.close();server.kill('SIGTERM');console.log(log)}
