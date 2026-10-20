// Destructive only to a newly allocated synthetic application in APXTM_VERIFY.
// A trusted full export is saved before alias/deletion tests and owner-reimported.
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import {createHash} from 'node:crypto';
import {connect,localConfig,oracledb} from '../scripts/lib/oracle.mjs';

if(!process.argv.includes('--disposable-lab'))throw new Error('Requires --disposable-lab.');
const cfg=await localConfig();
if(cfg.workspace!=='APXTM_VERIFY'||cfg.user.toUpperCase()!=='APXTM_VERIFY')throw new Error('Requires the isolated APXTM_VERIFY laboratory.');
let db=await connect();
const evidence={started:new Date().toISOString(),schema:cfg.user.toUpperCase(),checks:[],sourceFiles:{},
 removalApiDocumentation:'https://docs.oracle.com/en/database/oracle/apex/26.1/aeapi/APEX_APPLICATION_INSTALL.REMOVE_APPLICATION-Procedure.html'};
let app,ws,manager,original,baseline,backup,proposal,comparison,sourcePath,changedIdentity=false,policyOwned=false;
const actor='DB:'+cfg.user.toUpperCase();
const fixtureName='APXTM History Access Lab';
const alias=()=>`APXTM-HISTORY-LAB-${app}`;
const sanitize=x=>String(x).replaceAll(cfg.password,'[REDACTED]').replaceAll(cfg.adminPassword,'[REDACTED]');
async function value(sql,binds={}){return Object.values((await db.execute(sql,binds)).rows[0])[0];}
async function number(expression,binds={}){return(await db.execute(`begin :n:=${expression};end;`,{...binds,n:{dir:oracledb.BIND_OUT,type:oracledb.NUMBER}})).outBinds.n;}
async function rejects(fn,code=20020){await assert.rejects(fn,e=>e.errorNum===code,`Expected ORA-${code}`);}
async function reconnect(){await db.close();db=await connect();}
async function check(name,fn){try{const detail=await fn();evidence.checks.push({name,status:'PASS',detail});console.log('PASS',name);}catch(e){evidence.checks.push({name,status:'FAIL',error:sanitize(e.message)});throw e;}}
async function currentIdentity(){return(await db.execute('select application_name,alias,owner from apex_applications where application_id=:app and workspace_id=:ws',{app,ws})).rows;}
async function guardFixture(acceptChangedAlias=false){const rows=await currentIdentity();assert.equal(rows.length,1);assert.equal(rows[0].APPLICATION_NAME,fixtureName);assert.equal(rows[0].OWNER,cfg.user.toUpperCase());assert([alias(),...(acceptChangedAlias?[alias()+'-CHANGED']:[])].includes(rows[0].ALIAS));}
async function exportSource(){const r=await db.execute(`declare f apex_t_export_files;begin apex_util.set_security_group_id(:ws);
 f:=apex_export.get_application(p_application_id=>:app,p_type=>'SQL',p_split=>false,p_with_date=>false,
 p_with_original_ids=>false,p_with_no_subscriptions=>false,p_with_audit_info=>null,p_with_supporting_objects=>'N',
 p_with_acl_assignments=>true,p_with_ir_public_reports=>true,p_with_ir_private_reports=>true,
 p_with_ir_notifications=>true,p_with_translations=>true);:source:=f(1).contents;end;`,
 {app,ws,source:{dir:oracledb.BIND_OUT,type:oracledb.CLOB}});const lob=r.outBinds.source;
 if(typeof lob==='string')return lob;try{return await lob.getData();}finally{await lob.close();}}
async function importSource(source,applicationAlias,newApplication=false){
 const r=await db.execute(`declare f apex_t_export_files:=apex_t_export_files(apex_t_export_file(name=>'fixture.sql',contents=>:source));
 info apex_application_install.t_file_info;begin
 apex_util.set_security_group_id(:ws);apex_application_install.clear_all;
 info:=apex_application_install.get_info(f);
 if :new_app=0 and (info.app_id is null or info.app_id!=:existing_id or info.workspace_id!=:ws or upper(info.app_owner)!=upper(:owner)) then raise_application_error(-20998,'Saved fixture identity differs');end if;
 apex_application_install.set_workspace_id(:ws);apex_application_install.set_schema(:owner);
 if :new_app=1 then apex_application_install.generate_application_id;apex_application_install.generate_offset;
  :id:=apex_application_install.get_application_id;
 else :id:=:existing_id;apex_application_install.set_application_id(:existing_id);end if;
 apex_application_install.set_application_name(:name);
 apex_application_install.set_application_alias(case when :new_app=1 then 'APXTM-HISTORY-LAB-'||:id else :alias end);
 apex_application_install.set_auto_install_sup_obj(false);
 apex_application_install.install(p_source=>f,p_overwrite_existing=>:new_app=0);commit;end;`,{
 source:{val:source,type:oracledb.CLOB},ws,owner:cfg.user.toUpperCase(),new_app:newApplication?1:0,
 existing_id:app??null,name:fixtureName,alias:applicationAlias??null,id:{dir:oracledb.BIND_OUT,type:oracledb.NUMBER}});
 return r.outBinds.id;
}
async function historyDownloads(){
 const r=await db.execute(`declare z blob;f apex_t_export_files;info apex_application_install.t_file_info;begin
 if not apxtm_engine.validate_snapshot(:baseline) or not apxtm_engine.validate_snapshot(:backup) then raise_application_error(-20998,'Historical snapshot validation failed');end if;
 z:=apxtm_engine.snapshot_zip(:baseline);f:=apex_export.unzip(z);info:=apex_application_install.get_info(f);
 if info.app_id!=:app or info.workspace_id!=:ws or upper(info.app_owner)!=upper(:owner) then raise_application_error(-20998,'Baseline identity differs');end if;
 :baseline_hash:=rawtohex(dbms_crypto.hash(z,dbms_crypto.hash_sh256));
 z:=apxtm_engine.snapshot_zip(:backup);:backup_bytes:=dbms_lob.getlength(z);
 z:=apxtm_engine.operation_zip(:proposal);f:=apex_export.unzip(z);info:=apex_application_install.get_info(f);
 if info.app_id!=:app or info.workspace_id!=:ws or upper(info.app_owner)!=upper(:owner) then raise_application_error(-20998,'Proposal identity differs');end if;
 :proposal_bytes:=dbms_lob.getlength(z);end;`,{
 baseline,backup,proposal:proposal.id,app,ws,owner:cfg.user.toUpperCase(),
 baseline_hash:{dir:oracledb.BIND_OUT,type:oracledb.STRING,maxSize:64},
 backup_bytes:{dir:oracledb.BIND_OUT,type:oracledb.NUMBER},proposal_bytes:{dir:oracledb.BIND_OUT,type:oracledb.NUMBER}});
 assert(r.outBinds.backup_bytes>0);assert(r.outBinds.proposal_bytes>0);
 assert.equal(r.outBinds.baseline_hash,await value('select a.archive_hash from apxtm_snapshots s join apxtm_artifacts a on a.artifact_id=s.artifact_id where s.snapshot_id=:id',{id:baseline}));
 assert.equal(await value('select apxtm_engine.can_read_history(:app) from dual',{app}),1);
 return r.outBinds;
}
async function preview(){const r=await db.execute('begin apxtm_engine.preview_restore(:snapshot,:op,:token);end;',{
 snapshot:baseline,op:{dir:oracledb.BIND_OUT,type:oracledb.NUMBER},token:{dir:oracledb.BIND_OUT,type:oracledb.STRING,maxSize:128}});return{id:r.outBinds.op,token:r.outBinds.token};}
async function liveOperationsDeny(){
 assert.equal(await value('select apxtm_engine.allowed(:app) from dual',{app}),0);
 await rejects(()=>number('apxtm_engine.take_snapshot(:app)',{app}));
 await rejects(()=>number('apxtm_engine.compare(:id)',{id:baseline}));
 await rejects(()=>db.execute('declare op number;token varchar2(128);begin apxtm_engine.preview(:id,null,op,token);end;',{id:comparison}));
 await rejects(()=>preview());
 await rejects(()=>db.execute('begin apxtm_engine.apply(:id,:token,:confirmation);end;',{id:proposal.id,token:proposal.token,confirmation:`RESTORE ${app}`}));
 await rejects(()=>db.execute('begin apxtm_engine.retire_snapshot(:id,:confirmation);end;',{id:baseline,confirmation:`DELETE ${baseline}`}));
 assert.equal(await value('select status from apxtm_operations where operation_id=:id',{id:proposal.id}),'PREVIEW');
}
async function historyDeny(){
 assert.equal(await value('select apxtm_engine.can_read_history(:app) from dual',{app}),0);
 await rejects(()=>number('case when apxtm_engine.validate_snapshot(:id) then 1 else 0 end',{id:baseline}));
 await rejects(()=>db.execute('declare z blob;begin z:=apxtm_engine.snapshot_zip(:id);end;',{id:backup}));
 await rejects(()=>db.execute('declare z blob;begin z:=apxtm_engine.operation_zip(:id);end;',{id:proposal.id}));
}
async function temporaryDenial(name,sql,binds={}){await check(name,async()=>{try{await db.execute(sql,binds);await historyDeny();}finally{await db.rollback();}});}

try{
 for(const file of ['database/packages/apxtm_engine.pks','database/packages/apxtm_engine.pkb'])evidence.sourceFiles[file]={sha256:createHash('sha256').update(await fs.readFile(file)).digest('hex'),modified:(await fs.stat(file)).mtime.toISOString()};
 await check('guard isolated owner/workspace and allocate a new original synthetic application',async()=>{
  assert.equal(await value("select upper(sys_context('USERENV','SESSION_USER')) from dual"),'APXTM_VERIFY');
  ws=await value('select apex_util.find_security_group_id(:name) from dual',{name:cfg.workspace});assert(ws);
  const c=(await db.execute('select workspace_id,manager_app_id,modification_policy,lock_user from apxtm_config where config_id=1')).rows[0];
  assert.equal(c.WORKSPACE_ID,ws);assert.equal(c.MODIFICATION_POLICY,'DISABLED');assert(c.LOCK_USER);manager=c.MANAGER_APP_ID;
  assert.equal(await value('select permission_role from apxtm_principals where actor=:actor and enabled=\'Y\'',{actor}),'RESTORER');
  app=await importSource(await fs.readFile('samples/layout-lab/exports/baseline/f105.sql','utf8'),null,true);
  // Public import/export package globals are connection state. Export only from
  // a fresh owner session, matching the supported installation instructions.
  await reconnect();
  assert(![104,105,106,107,108,109,110].includes(app),'Never reuse another agent\'s application');await guardFixture();
  original=await exportSource();sourcePath=`.local/verify-history-source-${app}.sql`;await fs.writeFile(sourcePath,original);
  await db.execute('begin apxtm_engine.register_application(:app);end;',{app});
  evidence.applicationId=app;evidence.workspaceId=ws;evidence.savedTrustedSource={path:sourcePath,sha256:createHash('sha256').update(original).digest('hex')};
  return {applicationId:app,name:fixtureName,alias:alias()};
 });
 await check('create real preview, verified operation and durable pre-import backup',async()=>{
  baseline=await number("apxtm_engine.take_snapshot(:app,'History authorization baseline')",{app});
  policyOwned=true;
  await db.execute("update apxtm_config set modification_policy='DEVELOPMENT' where config_id=1");
  await db.execute("update apxtm_applications set allow_recovery='Y' where application_id=:app",{app});await db.commit();
  const op=await preview();await db.execute('begin apxtm_engine.apply(:id,:token,:confirmation);end;',{id:op.id,token:op.token,confirmation:`RESTORE ${app}`});
  const row=(await db.execute('select status,backup_snapshot_id from apxtm_operations where operation_id=:id',{id:op.id})).rows[0];assert.equal(row.STATUS,'VERIFIED');assert(row.BACKUP_SNAPSHOT_ID);backup=row.BACKUP_SNAPSHOT_ID;
  proposal=await preview();comparison=await number('apxtm_engine.compare(:id)',{id:baseline});
  evidence.history={baselineSnapshotId:baseline,backupSnapshotId:backup,verifiedOperationId:op.id,previewOperationId:proposal.id,comparisonId:comparison};return evidence.history;
 });
 await check('changed live alias retains validated baseline backup and proposal downloads',async()=>{
  await guardFixture();changedIdentity=true;await importSource(original,alias()+'-CHANGED');await reconnect();await guardFixture(true);
  return await historyDownloads();
 });
 await check('changed live alias still denies capture compare restore apply and retirement',liveOperationsDeny);
 await check('disabled modification policy and per-target recovery flag do not hide history',async()=>{
  await db.execute("update apxtm_config set modification_policy='DISABLED' where config_id=1");
  await db.execute("update apxtm_applications set allow_recovery='N' where application_id=:app",{app});await db.commit();
  return await historyDownloads();
 });
 await temporaryDenial('revoked principal denies all historical download APIs',"update apxtm_principals set enabled='N' where actor=:actor",{actor});
 await temporaryDenial('disabled allowlist entry denies history',"update apxtm_applications set enabled='N' where application_id=:app",{app});
 await temporaryDenial('registered workspace mismatch denies history','update apxtm_applications set workspace_id=workspace_id+1 where application_id=:app',{app});
 await temporaryDenial('configured workspace mismatch denies history','update apxtm_config set workspace_id=workspace_id+1 where config_id=1');
 await temporaryDenial('registered parsing-schema mismatch denies history',"update apxtm_applications set parsing_schema='APXTM_WRONG_SCHEMA' where application_id=:app",{app});
 await temporaryDenial('manager self-exclusion applies even to a registered historical target','update apxtm_config set manager_app_id=:app where config_id=1',{app});
 await check('reader role can download historical definitions without recovery authority',async()=>{try{await db.execute("update apxtm_principals set permission_role='READER' where actor=:actor",{actor});return await historyDownloads();}finally{await db.rollback();}});
 await check('unknown null and non-allowlisted IDs deny history',async()=>{for(const id of [null,-1,999999999,manager])assert.equal(await value('select apxtm_engine.can_read_history(:app) from dual',{app:id}),0);});
 await check('unauthorized authenticated manager user cannot read historical definitions',async()=>{
  const other=await connect();let session;
  try{const r=await other.execute('begin apex_util.set_security_group_id(:ws);apex_session.create_session(p_app_id=>:manager,p_page_id=>1,p_username=>\'APXTM_HISTORY_DENIED\');:id:=apex_application.g_instance;end;',{ws,manager,id:{dir:oracledb.BIND_OUT,type:oracledb.NUMBER}});session=r.outBinds.id;
   assert.equal(Object.values((await other.execute('select apxtm_engine.can_read_history(:app) from dual',{app})).rows[0])[0],0);
   await rejects(()=>other.execute('declare z blob;begin z:=apxtm_engine.snapshot_zip(:id);end;',{id:backup}));
  }finally{if(session)await other.execute('begin apex_session.delete_session(p_session_id=>:id);end;',{id:session});await other.close();}
 });
 await check('archive corruption remains rejected for snapshot and operation downloads',async()=>{
  let artifact,corruptSnapshot,corruptOperation;
  try{const r=await db.execute(`declare a apxtm_artifacts%rowtype;o apxtm_operations%rowtype;begin
   select f.* into a from apxtm_artifacts f join apxtm_snapshots s on s.artifact_id=f.artifact_id where s.snapshot_id=:snapshot;
   insert into apxtm_artifacts(application_id,workspace_id,source_hash,archive_hash,source_name,source_characters,component_count,apex_version,archive)
   values(a.application_id,a.workspace_id,rawtohex(dbms_crypto.randombytes(32)),a.archive_hash,a.source_name,a.source_characters,a.component_count,a.apex_version,to_blob(hextoraw('0000'))) returning artifact_id into :artifact;
   insert into apxtm_snapshots(artifact_id,snapshot_name,snapshot_kind,created_by) values(:artifact,'Deliberately corrupt history fixture','BACKUP',:actor) returning snapshot_id into :id;
   select * into o from apxtm_operations where operation_id=:proposal;
   insert into apxtm_operations(application_id,operation_kind,expected_artifact_id,proposed_artifact_id,selection,token_hash,selected_count,created_by)
   values(o.application_id,o.operation_kind,o.expected_artifact_id,:artifact,o.selection,rawtohex(dbms_crypto.randombytes(32)),o.selected_count,o.created_by) returning operation_id into :operation;end;`,{
   snapshot:baseline,actor,proposal:proposal.id,artifact:{dir:oracledb.BIND_OUT,type:oracledb.NUMBER},id:{dir:oracledb.BIND_OUT,type:oracledb.NUMBER},operation:{dir:oracledb.BIND_OUT,type:oracledb.NUMBER}});
   artifact=r.outBinds.artifact;corruptSnapshot=r.outBinds.id;corruptOperation=r.outBinds.operation;
   await rejects(()=>db.execute('declare z blob;begin z:=apxtm_engine.snapshot_zip(:id);end;',{id:corruptSnapshot}),20027);
   await rejects(()=>db.execute('declare z blob;begin z:=apxtm_engine.operation_zip(:id);end;',{id:corruptOperation}),20027);
  }finally{await db.rollback();}
  return {artifactId:artifact,snapshotId:corruptSnapshot,operationId:corruptOperation,fixturesRolledBack:true};
 });
 await check('hash-valid ZIP with a different exported application identity is rejected',async()=>{
  const r=await db.execute(`declare f apex_t_export_files;source clob;z blob;artifact number;components json_array_t;component_count number;begin
   f:=apex_export.unzip(apxtm_engine.snapshot_zip(:baseline));
   source:=regexp_replace(f(1).contents,'p_default_application_id=>[0-9]+','p_default_application_id=>'||to_char(:app+10000,'TM9'),1,1);
   if dbms_lob.compare(source,f(1).contents)=0 then raise_application_error(-20998,'Fixture application ID was not replaced');end if;
   f(1).contents:=source;z:=apex_export.zip(f);components:=apxtm_parse.parse(source);component_count:=components.get_size;
   insert into apxtm_artifacts(application_id,workspace_id,source_hash,archive_hash,source_name,source_characters,component_count,apex_version,archive)
   values(:app,:ws,rawtohex(dbms_crypto.hash(source,dbms_crypto.hash_sh256)),rawtohex(dbms_crypto.hash(z,dbms_crypto.hash_sh256)),
    f(1).name,dbms_lob.getlength(source),component_count,'26.2.0',z) returning artifact_id into artifact;
   insert into apxtm_snapshots(artifact_id,snapshot_name,snapshot_kind,created_by)
   values(artifact,'Hash-valid wrong-identity history fixture','BACKUP',:actor) returning snapshot_id into :id;end;`,{
   baseline,app,ws,actor,id:{dir:oracledb.BIND_OUT,type:oracledb.NUMBER}});
  try{await rejects(()=>db.execute('declare z blob;begin z:=apxtm_engine.snapshot_zip(:id);end;',{id:r.outBinds.id}),20026);}
  finally{await db.rollback();}
  return {snapshotId:r.outBinds.id,archiveAndSourceHashesValid:true,expectedError:20026,fixtureRolledBack:true};
 });
 await check('public REMOVE_APPLICATION removes only the guarded newly allocated fixture',async()=>{
  await guardFixture(true);assert(original&&await fs.readFile(sourcePath,'utf8')===original);
  await db.execute('begin apex_util.set_security_group_id(:ws);apex_application_install.clear_all;apex_application_install.set_workspace_id(:ws);apex_application_install.set_keep_sessions(false);apex_application_install.remove_application(p_application_id=>:app);commit;end;',{ws,app});
  assert.equal(await value('select count(*) from apex_applications where application_id=:app',{app}),0);return {applicationId:app,liveApplicationRows:0};
 });
 await check('absent target retains validated baseline backup and proposal downloads',historyDownloads);
 await check('absent target still denies all live operations despite enabled recovery policy',async()=>{
  await db.execute("update apxtm_config set modification_policy='DEVELOPMENT' where config_id=1");
  await db.execute("update apxtm_applications set allow_recovery='Y' where application_id=:app",{app});await db.commit();
  await liveOperationsDeny();
 });
}catch(e){evidence.error=sanitize(e.message);console.error(evidence.error);process.exitCode=1;}
finally{
 try{await db.rollback();
  if(original&&changedIdentity){await check('explicit owner reimport restores original synthetic identity and component IDs',async()=>{
   const rows=await currentIdentity();if(rows.length)await guardFixture(true);
   await importSource(original,alias());await reconnect();await guardFixture();
   const restored=await exportSource();const normalize=x=>x.replace(/^--   Exported By:[^\n]*/m,'--   Exported By:     APXTM');
   assert.equal(normalize(restored),normalize(original));return {applicationId:app,sourceHash:createHash('sha256').update(normalize(restored)).digest('hex')};
  });}
 }catch(e){evidence.cleanupError=sanitize(e.message);console.error('Cleanup failed:',evidence.cleanupError);process.exitCode=1;}
 try{if(app)await db.execute("update apxtm_applications set allow_recovery='N' where application_id=:app",{app});
  if(policyOwned)await db.execute("update apxtm_config set modification_policy='DISABLED' where config_id=1");await db.commit();
  evidence.finalState={modificationPolicy:await value('select modification_policy from apxtm_config where config_id=1'),
   targetAllowRecovery:app?await value('select allow_recovery from apxtm_applications where application_id=:app',{app}):null,
   invalidObjects:await value("select count(*) from user_objects where object_name like 'APXTM\\_%' escape '\\' and status!='VALID'")};
 }finally{await db.close();evidence.finished=new Date().toISOString();await fs.mkdir('.local/evidence',{recursive:true});
  const path=`.local/evidence/history-access-${app??'unallocated'}.json`;await fs.writeFile(path,JSON.stringify(evidence,null,2));console.log(JSON.stringify({applicationId:app,checks:evidence.checks.length,failures:evidence.checks.filter(x=>x.status==='FAIL').length,evidence:path}));}
}
