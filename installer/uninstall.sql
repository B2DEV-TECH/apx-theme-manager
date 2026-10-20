-- SPDX-License-Identifier: Apache-2.0
-- DESTRUCTIVE. Required VARCHAR2(300) bind :apxtm_uninstall_confirmation must
-- exactly equal 'DROP APXTM DATA IN <SESSION_USER>'. No default consent.
-- Fixed APXTM object names only. Never drops a workspace, application or schema.
whenever oserror exit failure rollback
whenever sqlerror exit failure rollback
set define off verify off echo off serveroutput on sqlblanklines on

prompt This removes all APXTM snapshots, backups, comparisons, operations, audit and packages.
prompt APEX applications and all unrelated schema objects must be handled separately by their owners.
declare
  l_owner varchar2(128) := sys_context('USERENV','SESSION_USER');
  l_count number;
  l_version number;
  l_policy varchar2(20);
  procedure drop_known(p_type varchar2,p_name varchar2) is
    l_exists number;
  begin
    select count(*) into l_exists from user_objects where object_type=p_type and object_name=p_name;
    if l_exists=1 then
      -- Both arguments come exclusively from the fixed list below, never user input.
      execute immediate 'drop '||p_type||' '||p_name||case when p_type='TABLE' then ' purge' end;
      dbms_output.put_line('Dropped '||p_type||' '||p_name);
    end if;
  end;
begin
  if l_owner<>sys_context('USERENV','CURRENT_SCHEMA')
     or sys_context('USERENV','PROXY_USER') is not null or l_owner in ('SYS','SYSTEM')
     or nvl(:apxtm_uninstall_confirmation,chr(0))<>'DROP APXTM DATA IN '||l_owner then
    raise_application_error(-20060,'Uninstall refused: direct owner and exact typed data-loss consent required');
  end if;
  select schema_version,modification_policy into l_version,l_policy from apxtm_config where config_id=1;
  if l_version<>1 then raise_application_error(-20060,'Uninstall supports schema version 1 only'); end if;
  if l_policy<>'DISABLED' then raise_application_error(-20060,'Disable recovery before uninstalling'); end if;
  select count(*) into l_count from apxtm_operations where status='APPLYING';
  if l_count<>0 then raise_application_error(-20060,'An operation is applying; do not uninstall'); end if;
  select count(*) into l_count from user_constraints child join user_constraints parent
    on child.r_constraint_name=parent.constraint_name
   where child.constraint_type='R' and child.r_owner=l_owner
     and parent.table_name in ('APXTM_CONFIG','APXTM_PRINCIPALS','APXTM_APPLICATIONS','APXTM_ARTIFACTS',
       'APXTM_SNAPSHOTS','APXTM_COMPARISONS','APXTM_DIFFERENCES','APXTM_OPERATIONS','APXTM_AUDIT')
     and child.table_name not in ('APXTM_CONFIG','APXTM_PRINCIPALS','APXTM_APPLICATIONS','APXTM_ARTIFACTS',
       'APXTM_SNAPSHOTS','APXTM_COMPARISONS','APXTM_DIFFERENCES','APXTM_OPERATIONS','APXTM_AUDIT');
  if l_count<>0 then raise_application_error(-20060,'Unrelated foreign keys reference APXTM tables; inspect dependencies first'); end if;
  drop_known('TABLE','APXTM_AUDIT');
  drop_known('TABLE','APXTM_OPERATIONS');
  drop_known('TABLE','APXTM_DIFFERENCES');
  drop_known('TABLE','APXTM_COMPARISONS');
  drop_known('TABLE','APXTM_SNAPSHOTS');
  drop_known('TABLE','APXTM_ARTIFACTS');
  drop_known('TABLE','APXTM_APPLICATIONS');
  drop_known('TABLE','APXTM_PRINCIPALS');
  drop_known('TABLE','APXTM_CONFIG');
  drop_known('PACKAGE','APXTM_ENGINE');
  drop_known('PACKAGE','APXTM_DIFF');
  drop_known('PACKAGE','APXTM_PARSE');
  dbms_output.put_line('APXTM version 1 objects removed. Manager application removal is a separate explicit App Builder action.');
end;
/
