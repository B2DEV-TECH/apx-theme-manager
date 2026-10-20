// Destructive tests are restricted to the original synthetic layout laboratory.
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import { performance } from 'node:perf_hooks';
import { connect, localConfig, oracledb } from '../scripts/lib/oracle.mjs';

if (!process.argv.includes('--disposable-lab')) throw new Error('Requires --disposable-lab; reads/writes the synthetic APXTM Layout Lab only.');
const config=await localConfig();
const db=await connect();
const evidence={started:new Date().toISOString(),tests:[],versions:{}};
let baselineId,comparisonId,appId,managerId,workspaceId;
async function test(name,fn){
 const start=performance.now();
 try{await fn();evidence.tests.push({name,status:'PASS',milliseconds:Math.round(performance.now()-start)});console.log('PASS',name);}
 catch(e){evidence.tests.push({name,status:'FAIL',error:e.message});console.error('FAIL',name,e.message);throw e;}
}
async function scalar(sql,binds={}){return Object.values((await db.execute(sql,binds)).rows[0])[0];}
async function callNumber(expression,binds={}){
 const r=await db.execute(`begin :result := ${expression}; end;`,{...binds,result:{dir:oracledb.BIND_OUT,type:oracledb.NUMBER}});return r.outBinds.result;
}
async function importSource(filename){
 const source=await fs.readFile(filename,'utf8');
 // GET_INFO verifies the checked-in synthetic export before the supported import.
 await db.execute(`declare f apex_t_export_files:=apex_t_export_files(apex_t_export_file(name=>'f'||:app||'.sql',contents=>:source));i apex_application_install.t_file_info;
 begin apex_util.set_security_group_id(:ws);apex_application_install.clear_all;i:=apex_application_install.get_info(f);
 if i.app_id!=:app or i.workspace_id!=:ws or upper(i.app_owner)!=:owner then raise_application_error(-20999,'Fixture identity mismatch');end if;
 apex_application_install.set_workspace_id(:ws);apex_application_install.set_application_id(:app);apex_application_install.set_schema(:owner);
 apex_application_install.set_auto_install_sup_obj(false);apex_application_install.install(p_source=>f,p_overwrite_existing=>true);end;`,
 {app:appId,ws:workspaceId,owner:config.user.toUpperCase(),source:{val:source,type:oracledb.CLOB}});
 // This connection owns the fixture import. INSTALL leaves metadata DML pending;
 // make the fixture durable before starting an independent recovery transaction.
 await db.commit();
}
async function preview(comparison,ids=null){
 const r=await db.execute('begin apxtm_engine.preview(:comparison,:ids,:op,:token);end;',{comparison,ids,
  op:{dir:oracledb.BIND_OUT,type:oracledb.NUMBER},token:{dir:oracledb.BIND_OUT,type:oracledb.STRING,maxSize:128}});
 return {id:r.outBinds.op,token:r.outBinds.token};
}
async function apply(op,confirmation=`APPLY ${appId}`){
 await db.execute('begin apxtm_engine.apply(:id,:token,:confirmation);end;',{id:op.id,token:op.token,confirmation});
}
async function reject(fn,code){await assert.rejects(fn,e=>e.errorNum===code,`Expected ORA-${code}`);}
try{
 await test('guard: target is the original synthetic app in the configured workspace',async()=>{
  const rows=await db.execute(`select application_id,application_name,alias,owner,workspace_id from apex_applications
    where workspace_id=apex_util.find_security_group_id(:ws) and alias in ('APEX-THEME-MANAGER','APXTM-LAYOUT-LAB')`,{ws:config.workspace});
  const app=rows.rows.find(x=>x.ALIAS==='APXTM-LAYOUT-LAB');const manager=rows.rows.find(x=>x.ALIAS==='APEX-THEME-MANAGER');
  assert(app&&manager);assert.equal(app.APPLICATION_NAME,'APXTM Layout Lab');assert.equal(app.OWNER,config.user.toUpperCase());
  appId=app.APPLICATION_ID;managerId=manager.APPLICATION_ID;workspaceId=app.WORKSPACE_ID;
  assert.notEqual(appId,managerId);evidence.versions.apex=await scalar('select version_no from apex_release');
  evidence.versions.database=await scalar("select product||' '||version_full from product_component_version where product like 'Oracle%'");
 });
 await test('explicit lab setup registers read-only before recovery enablement',async()=>{
  if(!await scalar('select count(*) from apxtm_applications where application_id=:app',{app:appId}))
   await db.execute('begin apxtm_engine.register_application(:app);end;',{app:appId});
  assert.equal(await scalar('select apxtm_engine.allowed(:app) from dual',{app:appId}),1);
  await db.execute("update apxtm_applications set allow_recovery='N' where application_id=:app",{app:appId});await db.commit();
  assert.equal(await scalar("select apxtm_engine.allowed(:app,'RECOVER') from dual",{app:appId}),0);
  const text=await fs.readFile('installer/enable_recovery.sql','utf8');const body=text.slice(text.indexOf('\ndeclare')+1,text.lastIndexOf('\n/'));
  await db.execute(body,{apxtm_target_app_id:appId,apxtm_lock_user:config.adminUser,apxtm_enable_confirmation:`ENABLE RECOVERY FOR ${appId}`});
  assert.equal(await scalar("select apxtm_engine.allowed(:app,'RECOVER') from dual",{app:appId}),1);
 });
 await test('baseline snapshot is durable and its ZIP/source integrity validates',async()=>{
  await importSource('samples/layout-lab/exports/baseline/f105.sql');
  baselineId=await callNumber("apxtm_engine.take_snapshot(:app,'Integration baseline')",{app:appId});
  assert.equal(await callNumber('case when apxtm_engine.validate_snapshot(:id) then 1 else 0 end',{id:baselineId}),1);
  const row=(await db.execute('select a.source_characters,dbms_lob.getlength(a.archive) archive_bytes,a.component_count from apxtm_snapshots s join apxtm_artifacts a on a.artifact_id=s.artifact_id where snapshot_id=:id',{id:baselineId})).rows[0];
  assert(row.SOURCE_CHARACTERS>10000&&row.ARCHIVE_BYTES>1000&&row.COMPONENT_COUNT>10);evidence.baseline=row;
 });
 await test('snapshot does not commit the caller transaction and identical exports deduplicate',async()=>{
  const observer=await connect();
  try{
   const before=await scalar('select to_char(updated_at,\'YYYY-MM-DD HH24:MI:SS.FF9 TZH:TZM\') from apxtm_config');
   await db.execute("update apxtm_config set updated_at=updated_at+interval '1' day where config_id=1");
   const another=await callNumber("apxtm_engine.take_snapshot(:app,'Transaction isolation probe')",{app:appId});
   const seen=Object.values((await observer.execute('select to_char(updated_at,\'YYYY-MM-DD HH24:MI:SS.FF9 TZH:TZM\') value from apxtm_config')).rows[0])[0];
   assert.equal(seen,before);await db.rollback();
   assert.equal(await scalar('select artifact_id from apxtm_snapshots where snapshot_id=:id',{id:another}),await scalar('select artifact_id from apxtm_snapshots where snapshot_id=:id',{id:baselineId}));
  }finally{await db.rollback();await observer.close();}
 });
 await test('unchanged application has no changed properties',async()=>{
  const id=await callNumber('apxtm_engine.compare(:baseline)',{baseline:baselineId});
  assert.equal(await scalar("select count(*) from apxtm_differences where comparison_id=:id and classification!='UNCHANGED'",{id}),0);
  assert((await scalar('select count(*) from apxtm_differences where comparison_id=:id',{id}))>20);
 });
 await test('independent APEXlang-authored modifications produce the expected semantic differences',async()=>{
  await importSource('samples/layout-lab/exports/changed/f105.sql');
  comparisonId=await callNumber('apxtm_engine.compare(:baseline)',{baseline:baselineId});
  const rows=(await db.execute("select component_name,property_name,baseline_value,current_value,classification,eligible from apxtm_differences where comparison_id=:id and classification!='UNCHANGED' order by page_id,component_type,component_name,property_name",{id:comparisonId})).rows;
  evidence.observedDifferences=rows;
  const span=rows.find(x=>x.COMPONENT_NAME==='P1_PROJECT'&&x.PROPERTY_NAME==='p_colspan');
  assert.deepEqual([span.BASELINE_VALUE,span.CURRENT_VALUE,span.CLASSIFICATION,span.ELIGIBLE],['6','12','CHANGED','Y']);
  const region=rows.find(x=>x.COMPONENT_NAME==='Project brief'&&x.PROPERTY_NAME==='p_plug_grid_column_span');
  assert(region&&region.BASELINE_VALUE==='6'&&region.CURRENT_VALUE==='8');
  assert(rows.filter(x=>x.ELIGIBLE==='Y').length>=6);
 });
 let selectedOp;
 await test('Fix Selected preview does not modify the application',async()=>{
  const id=await scalar("select difference_id from apxtm_differences where comparison_id=:id and component_name='P1_PROJECT' and property_name='p_colspan'",{id:comparisonId});
  selectedOp=await preview(comparisonId,String(id));
  const op=(await db.execute('select status,selected_count,backup_snapshot_id from apxtm_operations where operation_id=:id',{id:selectedOp.id})).rows[0];
  assert.deepEqual(op,{STATUS:'PREVIEW',SELECTED_COUNT:1,BACKUP_SNAPSHOT_ID:null});
  assert.equal(await scalar("select grid_column_span from apex_application_page_items where application_id=:app and item_name='P1_PROJECT'",{app:appId}),12);
 });
 await test('incorrect typed confirmation is rejected before any backup or import',async()=>{
  await reject(()=>apply(selectedOp,'APPLY WRONG APPLICATION'),20028);
  assert.equal(await scalar('select status from apxtm_operations where operation_id=:id',{id:selectedOp.id}),'PREVIEW');
 });
 await test('Fix Selected creates a verified backup and independently verifies the entire import',async()=>{
  await apply(selectedOp);
  const op=(await db.execute('select status,backup_snapshot_id,result_message from apxtm_operations where operation_id=:id',{id:selectedOp.id})).rows[0];
  assert.equal(op.STATUS,'VERIFIED');assert(op.BACKUP_SNAPSHOT_ID);
  assert.equal(await callNumber('case when apxtm_engine.validate_snapshot(:id) then 1 else 0 end',{id:op.BACKUP_SNAPSHOT_ID}),1);
  assert.equal(await scalar("select grid_column_span from apex_application_page_items where application_id=:app and item_name='P1_PROJECT'",{app:appId}),6);
  evidence.selectedRecovery={operationId:selectedOp.id,status:op.STATUS,backupSnapshotId:op.BACKUP_SNAPSHOT_ID};
 });
 await test('consumed recovery token cannot be replayed',async()=>{await reject(()=>apply(selectedOp),20028);});
 await test('Fix All Eligible recovers every remaining eligible scalar',async()=>{
  const id=await callNumber('apxtm_engine.compare(:baseline)',{baseline:baselineId});const op=await preview(id);await apply(op);
  assert.equal(await scalar('select status from apxtm_operations where operation_id=:id',{id:op.id}),'VERIFIED');
  const checked=await callNumber('apxtm_engine.compare(:baseline)',{baseline:baselineId});
  assert.equal(await scalar("select count(*) from apxtm_differences where comparison_id=:id and eligible='Y'",{id:checked}),0);
 });
 await test('full restore requires its separate confirmation and verifies the complete definition',async()=>{
  const r=await db.execute('begin apxtm_engine.preview_restore(:snap,:op,:token);end;',{snap:baselineId,op:{dir:oracledb.BIND_OUT,type:oracledb.NUMBER},token:{dir:oracledb.BIND_OUT,type:oracledb.STRING,maxSize:128}});
  const op={id:r.outBinds.op,token:r.outBinds.token};await reject(()=>apply(op),20028);await apply(op,`RESTORE ${appId}`);
  assert.equal(await scalar('select status from apxtm_operations where operation_id=:id',{id:op.id}),'VERIFIED');
 });
 await test('stale comparison rejects preview after an independent application edit',async()=>{
  const id=await callNumber('apxtm_engine.compare(:baseline)',{baseline:baselineId});await importSource('samples/layout-lab/exports/changed/f105.sql');
  await reject(()=>preview(id),20024);assert.equal(await scalar('select status from apxtm_comparisons where comparison_id=:id',{id}),'STALE');
 });
 await test('application edit after preview invalidates apply and preserves the later state',async()=>{
  const id=await callNumber('apxtm_engine.compare(:baseline)',{baseline:baselineId});const op=await preview(id);
  await importSource('samples/layout-lab/exports/baseline/f105.sql');await reject(()=>apply(op),20024);
  assert.equal(await scalar('select status from apxtm_operations where operation_id=:id',{id:op.id}),'INVALIDATED');
  assert.equal(await scalar("select grid_column_span from apex_application_page_items where application_id=:app and item_name='P1_PROJECT'",{app:appId}),6);
 });
 await test('manager self-target and unknown IDs are rejected server-side',async()=>{
  assert.equal(await scalar('select apxtm_engine.allowed(:id) from dual',{id:managerId}),0);
  await reject(()=>callNumber('apxtm_engine.take_snapshot(:id)',{id:managerId}),20020);
  await reject(()=>callNumber('apxtm_engine.take_snapshot(:id)',{id:999999999}),20020);
 });
 evidence.finished=new Date().toISOString();
 console.log(JSON.stringify({passed:evidence.tests.filter(x=>x.status==='PASS').length,failed:0}));
}finally{
 await db.close();await fs.mkdir('.local/evidence',{recursive:true});
 await fs.writeFile('.local/evidence/integration.json',JSON.stringify(evidence,null,2));
}
