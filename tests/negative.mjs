import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import {connect,localConfig,oracledb} from '../scripts/lib/oracle.mjs';
if(!process.argv.includes('--disposable-lab'))throw new Error('Requires --disposable-lab; synthetic laboratory only.');
const cfg=await localConfig();const db=await connect();const results=[];
let app,manager,ws,snapshot;
const actor='DB:'+cfg.user.toUpperCase();
async function value(sql,binds={}){return Object.values((await db.execute(sql,binds)).rows[0])[0];}
async function number(expression,binds={}){const r=await db.execute(`begin :out := ${expression};end;`,{...binds,out:{dir:oracledb.BIND_OUT,type:oracledb.NUMBER}});return r.outBinds.out;}
async function fails(fn,code){await assert.rejects(fn,e=>e.errorNum===code,`Expected ORA-${code}`);}
async function test(name,fn){try{await fn();results.push({name,status:'PASS'});console.log('PASS',name);}catch(e){results.push({name,status:'FAIL',error:e.message});throw e;}}
async function restorePreview(){const r=await db.execute('begin apxtm_engine.preview_restore(:snapshot,:op,:token);end;',{snapshot,op:{dir:oracledb.BIND_OUT,type:oracledb.NUMBER},token:{dir:oracledb.BIND_OUT,type:oracledb.STRING,maxSize:128}});return{id:r.outBinds.op,token:r.outBinds.token};}
async function apply(connection,op){return connection.execute('begin apxtm_engine.apply(:id,:token,:confirmation);end;',{id:op.id,token:op.token,confirmation:`RESTORE ${app}`});}
try{
 await test('guard exact workspace, synthetic target and manager identities',async()=>{
  ws=await value('select apex_util.find_security_group_id(:ws) from dual',{ws:cfg.workspace});
  const rows=(await db.execute("select application_id,alias,owner from apex_applications where workspace_id=:ws and alias in ('APEX-THEME-MANAGER','APXTM-LAYOUT-LAB')",{ws})).rows;
  assert.equal(rows.length,2);assert(rows.every(x=>x.OWNER===cfg.user.toUpperCase()));
  app=rows.find(x=>x.ALIAS==='APXTM-LAYOUT-LAB').APPLICATION_ID;manager=rows.find(x=>x.ALIAS==='APEX-THEME-MANAGER').APPLICATION_ID;
  snapshot=await number("apxtm_engine.take_snapshot(:app,'Negative-suite durable baseline')",{app});
 });
 await test('read-only principal cannot recover or restore',async()=>{
  try{
   await db.execute("update apxtm_principals set permission_role='READER' where actor=:actor",{actor});await db.commit();
   assert.equal(await value("select apxtm_engine.allowed(:app,'READ') from dual",{app}),1);
   assert.equal(await value("select apxtm_engine.allowed(:app,'RECOVER') from dual",{app}),0);
   await fails(()=>restorePreview(),20020);
  }finally{await db.execute("update apxtm_principals set permission_role='RESTORER' where actor=:actor",{actor});await db.commit();}
 });
 await test('registry workspace mismatch is rejected before export',async()=>{
  try{await db.execute('update apxtm_applications set workspace_id=workspace_id+1 where application_id=:app',{app});await db.commit();
   await fails(()=>number('apxtm_engine.take_snapshot(:app)',{app}),20020);
  }finally{await db.execute('update apxtm_applications set workspace_id=:ws where application_id=:app',{ws,app});await db.commit();}
 });
 await test('non-allowlisted and self applications are rejected',async()=>{
  await fails(()=>number('apxtm_engine.take_snapshot(:app)',{app:manager}),20020);
  await fails(()=>number('apxtm_engine.take_snapshot(:app)',{app:999999999}),20020);
 });
 await test('immutable snapshot, artifact and audit metadata reject updates',async()=>{
  await fails(()=>db.execute("update apxtm_snapshots set snapshot_name='tampered' where snapshot_id=:id",{id:snapshot}),20051);
  await fails(()=>db.execute("update apxtm_artifacts set source_hash=rpad('0',64,'0') where artifact_id=(select artifact_id from apxtm_snapshots where snapshot_id=:id)",{id:snapshot}),20051);
  await fails(()=>db.execute("update apxtm_audit set detail='tampered' where event_id=(select max(event_id) from apxtm_audit)"),20051);
  await db.rollback();
 });
 await test('corrupted archive fixture is rejected before decompression/import',async()=>{
  let artifactId,snapshotId;
  try{
   const r=await db.execute(`declare original apxtm_artifacts%rowtype;begin
    select a.* into original from apxtm_artifacts a join apxtm_snapshots s on s.artifact_id=a.artifact_id where s.snapshot_id=:snapshot;
    insert into apxtm_artifacts(application_id,workspace_id,source_hash,archive_hash,source_name,source_characters,component_count,apex_version,archive)
    values(original.application_id,original.workspace_id,rawtohex(dbms_crypto.randombytes(32)),original.archive_hash,original.source_name,original.source_characters,original.component_count,original.apex_version,to_blob(hextoraw('0000')))
    returning artifact_id into :artifact;
    insert into apxtm_snapshots(artifact_id,snapshot_name,snapshot_kind,created_by) values(:artifact,'Intentionally corrupted test archive','BACKUP',:actor) returning snapshot_id into :id;commit;end;`,
    {snapshot,actor,artifact:{dir:oracledb.BIND_OUT,type:oracledb.NUMBER},id:{dir:oracledb.BIND_OUT,type:oracledb.NUMBER}});
   artifactId=r.outBinds.artifact;snapshotId=r.outBinds.id;
   await fails(()=>number('case when apxtm_engine.validate_snapshot(:id) then 1 else 0 end',{id:snapshotId}),20027);
  }finally{
   if(snapshotId)await db.execute('delete from apxtm_snapshots where snapshot_id=:id',{id:snapshotId});
   if(artifactId)await db.execute('delete from apxtm_artifacts where artifact_id=:id',{id:artifactId});await db.commit();
  }
 });
 await test('expired operation token is rejected before claiming or importing',async()=>{
  const op=await restorePreview();await db.execute("update apxtm_operations set expires_at=systimestamp-interval '1' minute where operation_id=:id",{id:op.id});await db.commit();
  await fails(()=>apply(db,op),20028);assert.equal(await value('select status from apxtm_operations where operation_id=:id',{id:op.id}),'PREVIEW');
 });
 await test('unknown authenticated APEX principal is denied server-side',async()=>{
  const other=await connect();
  try{
   await other.execute("begin apex_session.create_session(p_app_id=>:manager,p_page_id=>1,p_username=>'APXTM_DENIED');end;",{manager});
   await fails(()=>other.execute('declare n number;begin n:=apxtm_engine.take_snapshot(:app);end;',{app}),20020);
  }finally{await other.close();}
 });
 await test('privileged principal in a different APEX application is denied',async()=>{
  const other=await connect();
  try{
   await other.execute('begin apex_session.create_session(p_app_id=>:app,p_page_id=>1,p_username=>:name);end;',{app,name:cfg.adminUser});
   await fails(()=>other.execute('begin apxtm_engine.assert_access(:app);end;',{app}),20020);
  }finally{await other.close();}
 });
 await test('export fingerprint is stable between database and authenticated APEX actors',async()=>{
  const other=await connect();
  try{
   const hash=await value('select a.source_hash from apxtm_snapshots s join apxtm_artifacts a on a.artifact_id=s.artifact_id where snapshot_id=:id',{id:snapshot});
   await other.execute('begin apex_session.create_session(p_app_id=>:manager,p_page_id=>1,p_username=>:name);end;',{manager,name:cfg.adminUser});
   const r=await other.execute("begin :id:=apxtm_engine.take_snapshot(:app,'APEX actor fingerprint');end;",{app,id:{dir:oracledb.BIND_OUT,type:oracledb.NUMBER}});
   const actual=Object.values((await other.execute('select a.source_hash from apxtm_snapshots s join apxtm_artifacts a on a.artifact_id=s.artifact_id where snapshot_id=:id',{id:r.outBinds.id})).rows[0])[0];
   assert.equal(actual,hash);
  }finally{await other.close();}
 });
 await test('concurrent recovery claims allow only one active import',async()=>{
  const first=await restorePreview();const second=await restorePreview();const a=await connect(),b=await connect();
  try{
   const out=await Promise.allSettled([apply(a,first),apply(b,second)]);
   assert.equal(out.filter(x=>x.status==='fulfilled').length,1,JSON.stringify(out.map(x=>({status:x.status,error:x.reason?.message}))));
   const error=out.find(x=>x.status==='rejected').reason;assert([1,20029].includes(error.errorNum),error.message);
   const statuses=(await db.execute('select status from apxtm_operations where operation_id in (:a,:b)',{a:first.id,b:second.id})).rows.map(x=>x.STATUS);
   assert.equal(statuses.filter(x=>x==='VERIFIED').length,1);
  }finally{await a.close();await b.close();}
 });
 await test('successful recovery releases its developer lock',async()=>{
  assert.equal(await value('select locked_by from apex_applications where application_id=:app',{app}),null);
 });
 console.log(JSON.stringify({passed:results.length,failed:0}));
}finally{
 await db.close();await fs.mkdir('.local/evidence',{recursive:true});await fs.writeFile('.local/evidence/negative.json',JSON.stringify({finished:new Date().toISOString(),tests:results},null,2));
}
