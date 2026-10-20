// This explicit local-lab test overwrites only the original synthetic sample.
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import path from 'node:path';
import { createHash } from 'node:crypto';
import { performance } from 'node:perf_hooks';
import { chromium } from 'playwright';
import { connect, localConfig, oracledb } from './lib/oracle.mjs';

if (!process.argv.includes('--disposable-lab')) throw new Error('Requires --disposable-lab. This test overwrites the original synthetic sample105.');
const config=await localConfig();
const db=await connect();
const sampleId=105,managerId=104;
// Keep the reviewed recording intact when rechecking later parser hardening.
const directory=path.resolve(process.argv.includes('--final-validation')?'.local/ui-final-validation':'.local/ui-agent-workflow');
await fs.mkdir(directory,{recursive:true});
await Promise.all(['failure.txt','failure.png'].map(file=>fs.rm(path.join(directory,file),{force:true})));
const record=process.argv.includes('--record');
const videoDirectory=path.join(directory,'video');
if(record)await fs.mkdir(videoDirectory,{recursive:true});
const evidence={started:new Date().toISOString(),sampleId,managerId,tests:[],operations:[],sampleScenes:[]};
const browser=await chromium.launch({executablePath:'C:/Program Files/Google/Chrome/Application/chrome.exe',headless:true});
const context=await browser.newContext({viewport:{width:1440,height:1080},acceptDownloads:true,
 ...(record?{recordVideo:{dir:videoDirectory,size:{width:1440,height:1080}}}:{})});
const clockOrigin=performance.now();
evidence.recording={requested:record,timeOrigin:'Browser context creation completed',label:'Automated browser / synthetic layout scenario',viewport:{width:1440,height:1080},videos:[]};
const recordedPages=[];context.on('page',p=>recordedPages.push({page:p,createdAtMs:Math.round(performance.now()-clockOrigin)}));
let page=await context.newPage();
function labelRecording(targetPage,role){const entry=recordedPages.find(x=>x.page===targetPage);if(entry)entry.role=role;}
labelRecording(page,'manager-workflow');
let samplePage;
page.setDefaultTimeout(30000);
const pageErrors=[];page.on('pageerror',e=>pageErrors.push(e.message));
evidence.httpPosts=[];const httpReads=[];
context.on('response',response=>{if(response.request().method()!=='POST')return;const parameters=new URLSearchParams(response.request().postData()||'');httpReads.push((async()=>{const status=response.status();const body=status>=300&&status<400?null:await response.text().catch(()=>null);evidence.httpPosts.push({request:parameters.get('p_request'),status,contentType:response.headers()['content-type']||null,responseCharacters:body===null?null:body.length});})());});
async function test(name,run){const startMs=Math.round(performance.now()-clockOrigin);try{await run();const endMs=Math.round(performance.now()-clockOrigin);evidence.tests.push({name,passed:true,startMs,endMs,milliseconds:endMs-startMs});console.log('PASS',name);}catch(error){const endMs=Math.round(performance.now()-clockOrigin);evidence.tests.push({name,passed:false,startMs,endMs,milliseconds:endMs-startMs,message:error.message});throw error;}}
async function scalar(sql,binds={}){return Object.values((await db.execute(sql,binds)).rows[0])[0];}
async function navigate(action){await Promise.all([page.waitForNavigation({waitUntil:'networkidle',timeout:120000}),action()]);}
async function screenshot(name){await page.screenshot({path:path.join(directory,name+'.png'),fullPage:true});}
async function sampleScene(name){
 if(!samplePage){samplePage=await context.newPage();labelRecording(samplePage,'sample-layout');samplePage.on('pageerror',error=>pageErrors.push(error.message));await samplePage.goto('http://127.0.0.1:8080/ords/f?p=105:1',{waitUntil:'networkidle'});}
 else await samplePage.reload({waitUntil:'networkidle'});
 if(await samplePage.locator('#P9999_USERNAME').count()){
  await samplePage.locator('#P9999_USERNAME').fill(config.adminUser);await samplePage.locator('#P9999_PASSWORD').fill(config.adminPassword);
  await Promise.all([samplePage.waitForNavigation({waitUntil:'networkidle'}),samplePage.getByRole('button',{name:'Sign In',exact:true}).click()]);
 }
 assert.match(await samplePage.title(),/Project Desk/);
 assert(!/(?:ORA-\d+|Error during rendering|cannot be rendered|Setting the Column to Automatic|Contact your application administrator)/i.test(await samplePage.locator('body').innerText()));
 await samplePage.bringToFront();await samplePage.screenshot({path:path.join(directory,name+'.png'),fullPage:true});
 const items=(await db.execute("select item_name,grid_column_span from apex_application_page_items where application_id=105 and page_id=1 order by item_name")).rows;
 evidence.sampleScenes.push({name,atMs:Math.round(performance.now()-clockOrigin),file:name+'.png',items});
 await Promise.all([samplePage.waitForNavigation({waitUntil:'networkidle'}),samplePage.getByRole('button',{name:'Open review',exact:true}).click()]);
 assert.match(await samplePage.title(),/Review Board/);
 assert(!/(?:ORA-\d+|Error during rendering|cannot be rendered|Setting the Column to Automatic|Contact your application administrator)/i.test(await samplePage.locator('body').innerText()));
 await samplePage.screenshot({path:path.join(directory,name+'-review.png'),fullPage:true});
 evidence.sampleScenes.push({name:name+'-review',atMs:Math.round(performance.now()-clockOrigin),file:name+'-review.png'});
 await Promise.all([samplePage.waitForNavigation({waitUntil:'networkidle'}),samplePage.getByRole('button',{name:'Back to desk',exact:true}).click()]);
 await page.bringToFront();
}
async function healthy(){const text=await page.locator('body').innerText();assert(!/(?:ORA-\d+|Error during rendering|An unexpected internal application error)/i.test(text),text.slice(-3500));}
async function installFixture(variant){
 const source=await fs.readFile(`samples/layout-lab/exports/${variant}/f105.sql`,'utf8');
 const workspaceId=await scalar('select apex_util.find_security_group_id(:workspace) from dual',{workspace:config.workspace});
 await db.execute(`declare
   files apex_t_export_files:=apex_t_export_files(apex_t_export_file(name=>'f105.sql',contents=>:source));
   info apex_application_install.t_file_info;
 begin
   apex_util.set_security_group_id(:workspace);
   apex_application_install.clear_all;
   info:=apex_application_install.get_info(files);
   if info.app_id!=105 or info.workspace_id!=:workspace or upper(info.app_owner)!=:owner then
     raise_application_error(-20999,'Synthetic fixture identity mismatch');
   end if;
   apex_application_install.set_workspace_id(:workspace);
   apex_application_install.set_application_id(105);
   apex_application_install.set_schema(:owner);
   apex_application_install.set_auto_install_sup_obj(false);
   apex_application_install.install(p_source=>files,p_overwrite_existing=>true);
 end;`,{source:{val:source,type:oracledb.CLOB},workspace:workspaceId,owner:config.user.toUpperCase()});
 await db.commit();
}
async function openApplications(){
 if(await page.getByRole('button',{name:'Back to applications',exact:true}).count())await navigate(()=>page.getByRole('button',{name:'Back to applications',exact:true}).click());
 else{if(await page.locator('#t_Button_navControl').getAttribute('aria-expanded')!=='true')await page.locator('#t_Button_navControl').click();await navigate(()=>page.locator('.a-TreeView-label').filter({hasText:/^Applications$/}).click());}
 await page.locator('#P10_APPLICATION_ID').selectOption(String(sampleId));
 await navigate(()=>page.getByRole('button',{name:'Open application',exact:true}).click());
 await healthy();
}
async function compare(baseline){await page.locator('#P10_BASELINE_ID').selectOption(String(baseline));await navigate(()=>page.getByRole('button',{name:'Compare with current',exact:true}).click());await healthy();return Number(await page.locator('#P20_COMPARISON_ID').inputValue());}
async function download(link,expectedHash,name){
 const [file]=await Promise.all([page.waitForEvent('download'),link.click()]);
 const destination=path.join(directory,name+'.zip');await file.saveAs(destination);
 const bytes=await fs.readFile(destination);
 assert.equal(bytes.subarray(0,4).toString('hex'),'504b0304');
 const sha256=createHash('sha256').update(bytes).digest('hex').toUpperCase();
 assert.equal(sha256,expectedHash.toUpperCase());
 return {bytes:bytes.length,filename:file.suggestedFilename(),sha256};
}
let baselineId,selectedOperation,allOperation,restoreOperation;
try{
 await test('guard exact synthetic application and authorized manager identities',async()=>{
  const rows=(await db.execute('select application_id,application_name,workspace_id,owner,locked_by,working_copy_name from apex_applications where application_id in (104,105) order by application_id')).rows;
  assert.equal(rows.length,2);assert.equal(rows[0].APPLICATION_NAME,'APEX Theme Manager');assert.equal(rows[1].APPLICATION_NAME,'APXTM Layout Lab');assert.equal(rows[0].WORKSPACE_ID,rows[1].WORKSPACE_ID);assert.equal(rows[1].OWNER,config.user.toUpperCase());
  assert.equal(rows[1].LOCKED_BY,null,'The synthetic application must be free of developer locks');assert.equal(rows[1].WORKING_COPY_NAME,null);
  assert.equal(await scalar("select apxtm_engine.allowed(105,'RESTORE') from dual"),1);
  evidence.versions={apex:await scalar('select version_no from apex_release'),database:db.oracleServerVersionString,chrome:browser.version()};
 });
 await test('native authentication and baseline capture',async()=>{
  await installFixture('baseline');
  await page.goto('http://127.0.0.1:8080/ords/f?p=104:1',{waitUntil:'networkidle'});
  await page.locator('#P9999_USERNAME').fill(config.adminUser);await page.locator('#P9999_PASSWORD').fill(config.adminPassword);
  await navigate(()=>page.getByRole('button',{name:'Sign In',exact:true}).click());
  await screenshot('00-overview');
  await navigate(()=>page.getByRole('button',{name:'Browse applications',exact:true}).click());
  await page.locator('#P10_APPLICATION_ID').selectOption(String(sampleId));await navigate(()=>page.getByRole('button',{name:'Open application',exact:true}).click());
  await page.locator('#P10_SNAPSHOT_NAME').fill('Browser workflow baseline');await navigate(()=>page.getByRole('button',{name:'Capture baseline',exact:true}).click());
  await healthy();baselineId=Number(await page.locator('#P10_BASELINE_ID').inputValue());assert(baselineId>0);
  assert.equal(await scalar('select created_by from apxtm_snapshots where snapshot_id=:id',{id:baselineId}),'APEX:'+config.adminUser.toUpperCase());
  await screenshot('01-baseline');
  await sampleScene('sample-baseline');
 });
 await test('snapshot download is an authorized byte-identical ZIP',async()=>{
  const row=page.getByRole('row').filter({hasText:'Browser workflow baseline'}).first();
  assert.equal(await row.count(),1,'The newest captured baseline must appear on the first native report page');
  const hash=await scalar('select a.archive_hash from apxtm_snapshots s join apxtm_artifacts a on a.artifact_id=s.artifact_id where snapshot_id=:id',{id:baselineId});
  evidence.snapshotDownload=await download(row.getByRole('link',{name:'Download ZIP'}),hash,'baseline');
 });
 await test('native comparison displays independent changed layout and eligible rows',async()=>{
  await installFixture('changed');await sampleScene('sample-changed');await compare(baselineId);
  await page.locator('#P20_ELIGIBLE').selectOption('Y');await navigate(()=>page.getByRole('button',{name:'Filter report',exact:true}).click());await healthy();
  assert(await page.locator('.apxtm-check').count()>1);await screenshot('02-comparison');
  await page.setViewportSize({width:390,height:844});await screenshot('02-comparison-mobile');await page.setViewportSize({width:1440,height:1080});
 });
 await test('stale comparison after export returns an explicit native rejection',async()=>{
  const comparison=Number(await page.locator('#P20_COMPARISON_ID').inputValue());
  const before=await scalar('select count(*) from apxtm_operations');
  await installFixture('baseline');await navigate(()=>page.getByRole('button',{name:'Preview all eligible',exact:true}).click());
  assert.match(await page.locator('body').innerText(),/Application changed after comparison; compare again/);
  assert.equal(await scalar('select status from apxtm_comparisons where comparison_id=:id',{id:comparison}),'STALE');
  assert.equal(await scalar('select count(*) from apxtm_operations'),before);await screenshot('02-stale-comparison-rejected');
  await installFixture('changed');await openApplications();await compare(baselineId);
  await page.locator('#P20_ELIGIBLE').selectOption('Y');await navigate(()=>page.getByRole('button',{name:'Filter report',exact:true}).click());
 });
 await test('empty selection is rejected before preview creation',async()=>{
  const before=await scalar('select count(*) from apxtm_operations where created_by=:actor',{actor:'APEX:'+config.adminUser.toUpperCase()});
  await navigate(()=>page.getByRole('button',{name:'Preview selected',exact:true}).click());
  assert.match(await page.locator('body').innerText(),/Select at least one eligible difference/);
  assert.equal(await scalar('select count(*) from apxtm_operations where created_by=:actor',{actor:'APEX:'+config.adminUser.toUpperCase()}),before);
 });
 await test('an unsafe isolated region span is rejected without creating a proposal',async()=>{
  const before=await scalar('select count(*) from apxtm_operations');
  await page.getByRole('row').filter({hasText:'Contact details'}).filter({hasText:'p_plug_grid_column_span'}).locator('.apxtm-check').check();
  await navigate(()=>page.getByRole('button',{name:'Preview selected',exact:true}).click());
  assert.match(await page.locator('body').innerText(),/Request failed[\s\S]*(?:grid|span|column|overlap)/i);
  assert.equal(await scalar('select count(*) from apxtm_operations'),before);
  assert.equal(await scalar("select grid_column_span from apex_application_page_regions where application_id=105 and page_id=1 and region_name='Contact details'"),4);
 });
 await test('stale preview after export is invalidated before backup or import',async()=>{
  await navigate(()=>page.getByRole('button',{name:'Preview all eligible',exact:true}).click());await healthy();
  const operation=Number(await page.locator('#P30_OPERATION_ID').inputValue());
  await installFixture('baseline');await page.locator('#P30_CONFIRMATION').fill('APPLY 105');
  await navigate(()=>page.getByRole('button',{name:'Apply reviewed operation',exact:true}).click());
  assert.match(await page.locator('body').innerText(),/Application changed after preview; compare again/);
  const result=(await db.execute('select status,backup_snapshot_id from apxtm_operations where operation_id=:id',{id:operation})).rows[0];
  assert.equal(result.STATUS,'INVALIDATED');assert.equal(result.BACKUP_SNAPSHOT_ID,null);await screenshot('02-stale-preview-rejected');
  await installFixture('changed');await openApplications();await compare(baselineId);
  await page.locator('#P20_ELIGIBLE').selectOption('Y');await navigate(()=>page.getByRole('button',{name:'Filter report',exact:true}).click());
 });
 await test('selected preview binds exactly one property and exposes proposed ZIP',async()=>{
  const row=page.getByRole('row').filter({hasText:'P1_PROJECT'}).filter({hasText:'p_colspan'});await row.locator('.apxtm-check').check();
  await navigate(()=>page.getByRole('button',{name:'Preview selected',exact:true}).click());await healthy();
  selectedOperation=Number(await page.locator('#P30_OPERATION_ID').inputValue());
  const op=(await db.execute('select status,selected_count,created_by from apxtm_operations where operation_id=:id',{id:selectedOperation})).rows[0];
  assert.equal(op.STATUS,'PREVIEW');assert.equal(op.SELECTED_COUNT,1);assert.equal(op.CREATED_BY,'APEX:'+config.adminUser.toUpperCase());
  assert.match(await page.locator('body').innerText(),/P1_PROJECT/);
  const hash=await scalar('select a.archive_hash from apxtm_operations o join apxtm_artifacts a on a.artifact_id=o.proposed_artifact_id where operation_id=:id',{id:selectedOperation});
  evidence.proposalDownload=await download(page.getByRole('link',{name:'Download proposed ZIP'}),hash,'proposal');await screenshot('03-preview-selected');
 });
 await test('wrong typed confirmation leaves the target and preview unchanged',async()=>{
  await page.locator('#P30_CONFIRMATION').fill('APPLY WRONG APPLICATION');await navigate(()=>page.getByRole('button',{name:'Apply reviewed operation',exact:true}).click());
  assert.match(await page.locator('body').innerText(),/Typed application confirmation does not match/);
  assert.equal(await scalar('select status from apxtm_operations where operation_id=:id',{id:selectedOperation}),'PREVIEW');
  assert.equal(await scalar("select grid_column_span from apex_application_page_items where application_id=105 and item_name='P1_PROJECT'"),12);
  await screenshot('04-confirmation-rejected');
 });
 await test('typed POST apply verifies selected recovery and persists backup',async()=>{
  await page.locator('#P30_CONFIRMATION').fill('APPLY 105');await navigate(()=>page.getByRole('button',{name:'Apply reviewed operation',exact:true}).click());await healthy();
  const op=(await db.execute('select status,backup_snapshot_id from apxtm_operations where operation_id=:id',{id:selectedOperation})).rows[0];assert.equal(op.STATUS,'VERIFIED');assert(op.BACKUP_SNAPSHOT_ID>0);
  assert.equal(await scalar("select grid_column_span from apex_application_page_items where application_id=105 and item_name='P1_PROJECT'"),6);
  evidence.operations.push({id:selectedOperation,kind:'RECOVER',selected:1,...op});await screenshot('05-selected-verified');
 });
 await test('all-eligible preview and typed POST apply verify remaining eligible properties',async()=>{
  await openApplications();const comparison=await compare(baselineId);await navigate(()=>page.getByRole('button',{name:'Preview all eligible',exact:true}).click());await healthy();
  allOperation=Number(await page.locator('#P30_OPERATION_ID').inputValue());await page.locator('#P30_CONFIRMATION').fill('APPLY 105');await navigate(()=>page.getByRole('button',{name:'Apply reviewed operation',exact:true}).click());await healthy();
  const op=(await db.execute('select status,selected_count,backup_snapshot_id from apxtm_operations where operation_id=:id',{id:allOperation})).rows[0];assert.equal(op.STATUS,'VERIFIED');assert(op.SELECTED_COUNT>1);assert(op.BACKUP_SNAPSHOT_ID>0);
  assert.equal(await scalar("select count(*) from apxtm_differences where comparison_id=:id and eligible='Y' and outcome!='FIXED'",{id:comparison}),0);
  for(const item of ['P1_EMAIL','P2_SUMMARY','P2_STATUS'])assert.equal(await scalar('select grid_column_span from apex_application_page_items where application_id=105 and item_name=:item',{item}),6);
  evidence.operations.push({id:allOperation,kind:'RECOVER',...op});await screenshot('06-all-verified');
  await sampleScene('sample-recovered-eligible');
 });
 await test('definition restore has separate preview and exact RESTORE confirmation',async()=>{
  await openApplications();await page.locator('#P10_BASELINE_ID').selectOption(String(baselineId));await navigate(()=>page.getByRole('button',{name:'Preview definition restore',exact:true}).click());await healthy();
  restoreOperation=Number(await page.locator('#P30_OPERATION_ID').inputValue());assert.match(await page.locator('body').innerText(),/RESTORE 105/);await screenshot('07-restore-preview');
  await page.locator('#P30_CONFIRMATION').fill('RESTORE 105');await navigate(()=>page.getByRole('button',{name:'Apply reviewed operation',exact:true}).click());await healthy();
  const op=(await db.execute('select status,backup_snapshot_id from apxtm_operations where operation_id=:id',{id:restoreOperation})).rows[0];assert.equal(op.STATUS,'VERIFIED');assert(op.BACKUP_SNAPSHOT_ID>0);
  evidence.operations.push({id:restoreOperation,kind:'RESTORE',...op});await screenshot('08-restore-verified');
  await sampleScene('sample-restored-definition');
 });
 await test('native audit shows browser operation outcomes without browser errors',async()=>{
  if(await page.locator('#t_Button_navControl').getAttribute('aria-expanded')!=='true')await page.locator('#t_Button_navControl').click();
  await navigate(()=>page.locator('.a-TreeView-label').filter({hasText:/^Activity$/}).click());await healthy();assert.match(await page.locator('body').innerText(),/VERIFIED/);
  assert.equal(await page.getByRole('heading',{name:'Definition snapshot history',exact:true}).count(),1);
  const operations=page.locator('.t-Region').filter({has:page.getByRole('heading',{name:'Recovery operations',exact:true})});
  const restoreRow=operations.getByRole('row').filter({hasText:'RESTORE'}).first();assert.match(await restoreRow.innerText(),new RegExp('\\b'+restoreOperation+'\\b'));
  const backupHash=await scalar('select a.archive_hash from apxtm_operations o join apxtm_snapshots s on s.snapshot_id=o.backup_snapshot_id join apxtm_artifacts a on a.artifact_id=s.artifact_id where o.operation_id=:id',{id:restoreOperation});
  evidence.backupDownload=await download(restoreRow.getByRole('link',{name:'Backup ZIP'}),backupHash,'restore-backup');
  await screenshot('09-audit');assert.deepEqual(pageErrors,[]);
 });
 await test('two tabs cannot silently apply a later preview for the same application',async()=>{
  await installFixture('changed');await openApplications();await compare(baselineId);
  await page.locator('#P20_ELIGIBLE').selectOption('Y');await navigate(()=>page.getByRole('button',{name:'Filter report',exact:true}).click());
  await page.getByRole('row').filter({hasText:'P1_PROJECT'}).filter({hasText:'p_colspan'}).locator('.apxtm-check').check();
  await navigate(()=>page.getByRole('button',{name:'Preview selected',exact:true}).click());await healthy();
  const tabA=page,opA=Number(await tabA.locator('#P30_OPERATION_ID').inputValue());
  const sessionA=await tabA.locator('input[name="p_instance"]').inputValue();
  const tabB=await context.newPage();labelRecording(tabB,'two-tab-preview');tabB.on('pageerror',error=>pageErrors.push(error.message));
  await tabB.goto(tabA.url(),{waitUntil:'networkidle'});
  assert.equal(await tabB.locator('input[name="p_instance"]').inputValue(),sessionA);
  page=tabB;await openApplications();await compare(baselineId);
  await navigate(()=>page.getByRole('button',{name:'Preview all eligible',exact:true}).click());await healthy();
  const opB=Number(await page.locator('#P30_OPERATION_ID').inputValue());assert.notEqual(opA,opB);
  assert(await scalar('select selected_count from apxtm_operations where operation_id=:id',{id:opB})>1);
  page=tabA;await page.locator('#P30_CONFIRMATION').fill('APPLY 105');await navigate(()=>page.getByRole('button',{name:'Apply reviewed operation',exact:true}).click());
  const a=(await db.execute('select status,backup_snapshot_id from apxtm_operations where operation_id=:id',{id:opA})).rows[0];
  const b=(await db.execute('select status,backup_snapshot_id from apxtm_operations where operation_id=:id',{id:opB})).rows[0];
  assert.equal(b.STATUS,'PREVIEW','Submitting tab A must never apply tab B');assert.equal(b.BACKUP_SNAPSHOT_ID,null);
  assert(['PREVIEW','VERIFIED'].includes(a.STATUS));
  if(a.STATUS==='PREVIEW')assert.match(await page.locator('body').innerText(),/session state|checksum|protected|unauthorized/i);
  else assert.equal(await scalar("select grid_column_span from apex_application_page_items where application_id=105 and item_name='P1_PROJECT'"),6);
  assert.equal(await scalar("select grid_column_span from apex_application_page_items where application_id=105 and item_name='P2_SUMMARY'"),9,'Tab B selection must remain unapplied');
  evidence.twoTabBinding={operationA:opA,statusA:a.STATUS,operationB:opB,statusB:b.STATUS};await screenshot('10-two-tab-binding');
  await tabB.close();await installFixture('baseline');
 });
 await test('all submitted export paths return nonempty pages or explicit redirects',async()=>{
  await Promise.all(httpReads);assert.deepEqual(evidence.httpPosts.filter(r=>r.status===200&&r.responseCharacters===0),[]);
  for(const request of ['CAPTURE','COMPARE','PREVIEW_SELECTED','PREVIEW_ALL','RESTORE','APPLY'])assert(evidence.httpPosts.some(r=>r.request===request&&r.status===302),request+' needs a native redirect');
 });
}catch(error){await screenshot('failure').catch(()=>{});await fs.writeFile(path.join(directory,'failure.txt'),await page.locator('body').innerText()).catch(()=>{});process.exitCode=1;console.error(error.message);}
finally{
 evidence.finished=new Date().toISOString();evidence.pageErrors=pageErrors;
 await Promise.all(httpReads);
 await context.close();
 if(record)for(let i=0;i<recordedPages.length;i++){
  const video=recordedPages[i].page.video();
  if(video){const role=recordedPages[i].role||`secondary-tab-${i}`;const destination=path.join(videoDirectory,role+'.webm');await video.saveAs(destination);evidence.recording.videos.push({page:i+1,role,createdAtMs:recordedPages[i].createdAtMs,file:destination});}
 }
 await fs.writeFile(path.join(directory,'results.json'),JSON.stringify(evidence,null,2));
 await browser.close();await db.close();
}
