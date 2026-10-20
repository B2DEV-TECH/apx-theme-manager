-- SPDX-License-Identifier: Apache-2.0
-- Structural verification only; this does not exercise export/import or browser flows.
whenever oserror exit failure rollback
whenever sqlerror exit failure rollback
set define off verify off echo off serveroutput on sqlblanklines on

declare
  l_count number;
  l_version number;
  l_failed boolean := false;
begin
  for r in (select name,type,line,position,text from user_errors
             where name in ('APXTM_PARSE','APXTM_DIFF','APXTM_ENGINE',
               'APXTM_SNAPSHOT_IMMUTABLE','APXTM_ARTIFACT_IMMUTABLE','APXTM_AUDIT_IMMUTABLE')
               and attribute='ERROR' order by name,type,sequence) loop
    l_failed := true;
    dbms_output.put_line(r.name||' '||r.type||' '||r.line||':'||r.position||' '||r.text);
  end loop;
  if l_failed then raise_application_error(-20060,'APXTM compilation errors; inspect USER_ERRORS'); end if;
  select count(*) into l_count from user_objects where status='VALID' and
    ((object_name in ('APXTM_PARSE','APXTM_DIFF','APXTM_ENGINE') and object_type in ('PACKAGE','PACKAGE BODY'))
     or (object_name in ('APXTM_SNAPSHOT_IMMUTABLE','APXTM_ARTIFACT_IMMUTABLE','APXTM_AUDIT_IMMUTABLE')
         and object_type='TRIGGER'));
  if l_count<>9 then raise_application_error(-20060,'Expected six valid package units and three valid triggers'); end if;
  select count(*) into l_count from user_tables where table_name in
    ('APXTM_CONFIG','APXTM_PRINCIPALS','APXTM_APPLICATIONS','APXTM_ARTIFACTS',
     'APXTM_SNAPSHOTS','APXTM_COMPARISONS','APXTM_DIFFERENCES','APXTM_OPERATIONS','APXTM_AUDIT');
  if l_count<>9 then raise_application_error(-20060,'Expected nine APXTM tables'); end if;
  select schema_version into l_version from apxtm_config where config_id=1;
  if l_version<>1 then raise_application_error(-20060,'Unsupported APXTM schema version'); end if;
  dbms_output.put_line('APXTM schema version 1; required objects are present and valid.');
end;
/
select workspace_id,manager_app_id,modification_policy,lock_user from apxtm_config where config_id=1;
select permission_role,enabled,count(*) principal_count from apxtm_principals group by permission_role,enabled;
select application_id,workspace_id,allow_recovery,enabled from apxtm_applications order by application_id;
