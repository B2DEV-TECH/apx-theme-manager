import fs from 'node:fs/promises';
import path from 'node:path';
import { chromium } from 'playwright';
import { localConfig } from './lib/oracle.mjs';

const config=await localConfig();
const browser=await chromium.launch({executablePath:'C:/Program Files/Google/Chrome/Application/chrome.exe',headless:true});
const screenshotDir=path.resolve('.local/ui-agent-browser');
await fs.mkdir(screenshotDir,{recursive:true});
const errors=[];
const context=await browser.newContext({viewport:{width:1440,height:1080}});
const page=await context.newPage();
page.on('pageerror',error=>errors.push(error.message));
const steps=[];
let snapshotUrl;
async function navigate(action){await Promise.all([page.waitForNavigation({waitUntil:'networkidle'}),action()]);}
async function inspect(name){
 await page.waitForLoadState('networkidle');
 const message=await page.locator('body').innerText();
 if(/(?:ORA-\d+|Error during rendering|An unexpected internal application error|Access denied|Your account does not have permission|Insufficient privileges)/i.test(message)){
  throw new Error(name+': '+message.slice(-3000));
 }
 await page.screenshot({path:path.join(screenshotDir,name+'.png'),fullPage:true});
 const width=await page.evaluate(()=>({viewport:window.innerWidth,document:document.documentElement.scrollWidth}));
 if(width.document>width.viewport+2)throw new Error(`${name}: page overflows viewport (${width.document}>${width.viewport})`);
 const tables=await page.getByRole('table').count();
 const scrollableTables=await page.locator('.t-Report-wrap').evaluateAll(nodes=>nodes.filter(node=>{
  if(node.scrollWidth<=node.clientWidth)return false;
  node.scrollLeft=30;const moved=node.scrollLeft>0;node.scrollLeft=0;return moved;
 }).length);
 if(width.viewport<640&&tables>0&&scrollableTables===0)throw new Error(name+': wide mobile tables are not scrollable');
 steps.push({name,title:await page.title(),tables,width,scrollableTables,visibleText:message.slice(0,2200)});
}
try{
 await page.goto('http://127.0.0.1:8080/ords/f?p=104:1',{waitUntil:'networkidle'});
 if(await page.locator('#P9999_USERNAME').count()){
  await page.locator('#P9999_USERNAME').fill(config.adminUser);
  await page.locator('#P9999_PASSWORD').fill(config.adminPassword);
  await Promise.all([page.waitForURL(url=>!url.toString().includes('/login')),page.getByRole('button',{name:'Sign In',exact:true}).click()]);
 }
 await inspect('overview-desktop');
 await navigate(()=>page.getByRole('button',{name:'Browse applications',exact:true}).click());
 await inspect('applications-empty');
 if(await page.locator('#P10_APPLICATION_ID option[value="105"]').count()){
  await page.locator('#P10_APPLICATION_ID').selectOption('105');
  await navigate(()=>page.getByRole('button',{name:'Open application',exact:true}).click());
  await inspect('application-detail');
  snapshotUrl=await page.getByRole('link',{name:'Download ZIP',exact:true}).first().getAttribute('href');
  snapshotUrl=new URL(snapshotUrl,page.url()).href;
  await page.setViewportSize({width:390,height:844});
  await inspect('application-mobile');
  await page.setViewportSize({width:1440,height:1080});
 }else{throw new Error('The original synthetic application105 is not visible to the authenticated lab actor.');}
 if(await page.locator('#t_Button_navControl').getAttribute('aria-expanded')!=='true')await page.locator('#t_Button_navControl').click();
 await navigate(()=>page.locator('.a-TreeView-label').filter({hasText:/^Guide$/}).click());
 await inspect('guide-desktop');
 await page.setViewportSize({width:390,height:844});
 await inspect('guide-mobile');
 const unauthenticated=await browser.newContext({viewport:{width:390,height:844}});
 try{
  const anonymous=await unauthenticated.newPage();let leakedDownload=false;
  anonymous.on('download',()=>{leakedDownload=true;});
  await anonymous.goto(snapshotUrl,{waitUntil:'networkidle'});
  const text=await anonymous.locator('body').innerText();
  if(leakedDownload)throw new Error('An unauthenticated browser received a definition archive');
  if(!await anonymous.locator('#P9999_USERNAME').isVisible()&&!/(?:access|checksum|session|sign in|log in)/i.test(text))throw new Error('Anonymous download did not show an authentication/access boundary');
  steps.push({name:'anonymous-download-denied',downloadReceived:false,authenticationRequired:await anonymous.locator('#P9999_USERNAME').isVisible()});
 }finally{await unauthenticated.close();}
 await fs.writeFile(path.join(screenshotDir,'results.json'),JSON.stringify({steps,errors},null,2));
 console.log(JSON.stringify({steps:steps.map(({name,title,tables})=>({name,title,tables})),pageErrors:errors,screenshots:screenshotDir},null,2));
 if(errors.length) process.exitCode=1;
}catch(error){
 await page.screenshot({path:path.join(screenshotDir,'failure.png'),fullPage:true}).catch(()=>{});
 await fs.writeFile(path.join(screenshotDir,'failure.txt'),await page.locator('body').innerText()).catch(()=>{});
 throw error;
}finally{await browser.close();}
