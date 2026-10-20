// Deliberate invalid installation in a newly allocated synthetic application.
// Never point this at an existing application. A failed import may be partial.
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import {connect,localConfig,oracledb} from '../scripts/lib/oracle.mjs';
if(!process.argv.includes('--disposable-lab'))throw new Error('Requires --disposable-lab.');
const cfg=await localConfig();
if(cfg.workspace!=='APXTM_VERIFY'||cfg.user.toUpperCase()!=='APXTM_VERIFY')throw new Error('This failure fixture requires the isolated APXTM_VERIFY laboratory.');
const db=await connect();const evidence={started:new Date().toISOString(),checks:[]};let app,ws,original;
async function value(sql,binds={}){return Object.values((await db.execute(sql,binds)).rows[0])[0];}
async function number(expression,binds={}){return (await db.execute(`begin :n:=${expression};end;`,{...binds,n:{dir:oracledb.BIND_OUT,type:oracledb.NUMBER}})).outBinds.n;}
async function importFiles(source,newApp=false){
 const r=await db.execute(`declare f apex_t_export_files:=apex_t_export_files(apex_t_export_file(name=>'fixture.sql',contents=>:source));begin
 apex_util.set_security_group_id(:ws);apex_application_install.clear_all;
 apex_application_install.set_workspace_id(:ws);apex_application_install.set_schema(:owner);
 if :new_app=1 then apex_application_install.generate_application_id;apex_application_install.generate_offset;
  :id:=apex_application_install.get_application_id;
  apex_application_install.set_application_alias('APXTM-FAILURE-LAB-'||:id);
  apex_application_install.set_application_name('APXTM Failure Lab');
 else :id:=:existing_id;apex_application_install.set_application_id(:existing_id);end if;
 apex_application_install.set_auto_install_sup_obj(false);
 apex_application_install.install(p_source=>f,p_overwrite_existing=>:new_app=0);commit;end;`,{
 source:{val:source,type:oracledb.CLOB},ws,owner:cfg.user.toUpperCase(),new_app:newApp?1:0,existing_id:app??null,
 id:{dir:oracledb.BIND_OUT,type:oracledb.NUMBER}});return r.outBinds.id;
}
try{
 ws=await value('select apex_util.find_security_group_id(:ws) from dual',{ws:cfg.workspace});assert(ws);
 app=await importFiles(await fs.readFile('samples/layout-lab/exports/baseline/f105.sql','utf8'),true);
 evidence.applicationId=app;
 assert.equal(await value('select application_name from apex_applications where application_id=:app and workspace_id=:ws',{app,ws}),'APXTM Failure Lab');
 await db.execute('begin apxtm_engine.register_application(:app);end;',{app});
 // Existing manager configuration is left intact. This target alone is enabled.
 await db.execute("update apxtm_config set modification_policy='DEVELOPMENT' where config_id=1");
 await db.execute("update apxtm_applications set allow_recovery='Y' where application_id=:app",{app});await db.commit();
 const good=await number("apxtm_engine.take_snapshot(:app,'Failure test: original durable definition')",{app});
 const exported=await db.execute('declare f apex_t_export_files;begin f:=apex_export.unzip(apxtm_engine.snapshot_zip(:id));:source:=f(1).contents;end;',{
  id:good,source:{dir:oracledb.BIND_OUT,type:oracledb.CLOB}});
 const lob=exported.outBinds.source;original=typeof lob==='string'?lob:await lob.getData();if(typeof lob!=='string')await lob.close();
 const parsed=await db.execute('declare a json_array_t;begin a:=apxtm_parse.parse(:source);:json:=a.to_clob;end;',{
  source:{val:original,type:oracledb.CLOB},json:{dir:oracledb.BIND_OUT,type:oracledb.CLOB}});
 const j=parsed.outBinds.json;const components=JSON.parse(typeof j==='string'?j:await j.getData());if(typeof j!=='string')await j.close();
 const item=components.find(x=>x.kind==='ITEM'&&x.name==='P1_PROJECT');assert(item);
 const span=item.spans.p_colspan;const chars=Array.from(original);
 const bad=chars.slice(0,span.start-1).join('')+"'APXTM_INTENTIONAL_IMPORT_FAILURE'"+chars.slice(span.end).join('');
 const fixture=await db.execute(`declare
 f apex_t_export_files:=apex_t_export_files(apex_t_export_file(name=>'f'||:app||'.sql',contents=>:source));
 z blob;a json_array_t;n number;artifact number;
 begin z:=apex_export.zip(f);a:=apxtm_parse.parse(:source);n:=a.get_size;
 insert into apxtm_artifacts(application_id,workspace_id,source_hash,archive_hash,source_name,source_characters,component_count,apex_version,archive)
 values(:app,:ws,rawtohex(dbms_crypto.hash(:source,dbms_crypto.hash_sh256)),rawtohex(dbms_crypto.hash(z,dbms_crypto.hash_sh256)),
 'f'||:app||'.sql',dbms_lob.getlength(:source),n,'26.2.0',z) returning artifact_id into artifact;
 insert into apxtm_snapshots(artifact_id,snapshot_name,snapshot_kind,created_by)
 values(artifact,'Intentionally invalid numeric import fixture','BASELINE',apxtm_engine.actor) returning snapshot_id into :id;commit;end;`,{
 app,ws,source:{val:bad,type:oracledb.CLOB},id:{dir:oracledb.BIND_OUT,type:oracledb.NUMBER}});
 const r=await db.execute('begin apxtm_engine.preview_restore(:snapshot,:op,:token);end;',{
  snapshot:fixture.outBinds.id,op:{dir:oracledb.BIND_OUT,type:oracledb.NUMBER},token:{dir:oracledb.BIND_OUT,type:oracledb.STRING,maxSize:128}});
 let failed=false;
 try{await db.execute('begin apxtm_engine.apply(:op,:token,:confirmation);end;',{op:r.outBinds.op,token:r.outBinds.token,confirmation:`RESTORE ${app}`});}
 catch(e){
  failed=true;evidence.installErrorCode=e.errorNum;
  assert(![20020,20024,20026,20027,20028,20029,20030,20031].includes(e.errorNum),'The test must reach native installation, not a permission/freshness/integrity/post-verification guard.');
  assert.equal(e.errorNum,20987,'Expected the tested APEX native installation failure wrapper.');
  evidence.installError=e.message.split('\n')[0];
 }
 assert(failed,'The deliberately invalid numeric installation must fail.');
 const op=(await db.execute('select status,error_code,backup_snapshot_id from apxtm_operations where operation_id=:id',{id:r.outBinds.op})).rows[0];
 assert.equal(op.STATUS,'FAILED');assert(op.BACKUP_SNAPSHOT_ID);
 assert.equal(await number('case when apxtm_engine.validate_snapshot(:id) then 1 else 0 end',{id:op.BACKUP_SNAPSHOT_ID}),1);
 evidence.checks.push({name:'native INSTALL failure leaves FAILED operation and independently valid durable backup',status:'PASS',operationId:r.outBinds.op,...op});
 evidence.applicationExistsAfterFailure=await value('select count(*) from apex_applications where application_id=:app',{app});
 // Recovery here is an explicit owner import into this newly created fault lab.
 await importFiles(original);assert.equal(await value("select grid_column_span from apex_application_page_items where application_id=:app and item_name='P1_PROJECT'",{app}),6);
 evidence.checks.push({name:'explicit owner reimport recovers the synthetic fault application',status:'PASS'});
 console.log(JSON.stringify({applicationId:app,checks:evidence.checks,applicationExistsAfterFailure:evidence.applicationExistsAfterFailure},null,2));
}finally{
 if(app)await db.execute("update apxtm_applications set allow_recovery='N' where application_id=:app",{app});
 await db.execute("update apxtm_config set modification_policy='DISABLED' where config_id=1");await db.commit();
 evidence.finished=new Date().toISOString();await db.close();await fs.mkdir('.local/evidence',{recursive:true});
 await fs.writeFile('.local/evidence/import-failure.json',JSON.stringify(evidence,null,2));
}
