-- SPDX-License-Identifier: Apache-2.0
-- Required binds: NUMBER :apxtm_target_app_id, VARCHAR2(255) :apxtm_lock_user,
-- VARCHAR2(300) :apxtm_enable_confirmation = 'ENABLE RECOVERY FOR <application ID>'.
-- This is an explicit owner operation for a disposable DEVELOPMENT target.
whenever oserror exit failure rollback
whenever sqlerror exit failure rollback
set define off verify off echo off serveroutput on sqlblanklines on

declare
  l_app_id number := :apxtm_target_app_id;
  l_lock_user varchar2(255) := upper(trim(:apxtm_lock_user));
  l_owner varchar2(300) := 'DB:'||upper(sys_context('USERENV','SESSION_USER'));
  l_config apxtm_config%rowtype;
  l_count number;
begin
  if apxtm_engine.actor<>l_owner
     or sys_context('USERENV','SESSION_USER')<>sys_context('USERENV','CURRENT_SCHEMA')
     or sys_context('USERENV','PROXY_USER') is not null then
    raise_application_error(-20060,'Enabling recovery requires a direct database owner session');
  end if;
  if l_app_id is null or l_app_id<=0 or l_app_id<>trunc(l_app_id) or l_lock_user is null then
    raise_application_error(-20060,'Set target application ID and existing lock developer binds');
  end if;
  if nvl(:apxtm_enable_confirmation,chr(0)) <> 'ENABLE RECOVERY FOR '||to_char(l_app_id,'TM9') then
    raise_application_error(-20060,'Typed recovery enablement confirmation does not match');
  end if;
  select * into l_config from apxtm_config where config_id=1 for update;
  if l_config.schema_version<>1 or l_config.workspace_id is null or l_config.manager_app_id is null then
    raise_application_error(-20060,'Configure the existing workspace and manager before enabling recovery');
  end if;
  if l_app_id=l_config.manager_app_id then raise_application_error(-20060,'Recovery of the manager itself is forbidden'); end if;
  apex_util.set_security_group_id(l_config.workspace_id);
  -- RESTORE target checks require an already enabled policy. Bootstrap using
  -- read-only target identity checks, then verify the owner's role separately.
  apxtm_engine.assert_access(l_app_id,'READ');
  if not apxtm_engine.has_permission('RESTORE') then
    raise_application_error(-20060,'Owner must have explicit RESTORER authority before enabling recovery');
  end if;
  select count(*) into l_count from apex_applications a join apxtm_applications r
    on r.application_id=a.application_id and r.workspace_id=a.workspace_id
     and r.parsing_schema=a.owner and r.application_alias=a.alias
   where a.application_id=l_app_id and a.workspace_id=l_config.workspace_id and r.enabled='Y'
     and a.build_status='Run and Develop' and a.working_copy_name is null;
  if l_count<>1 then raise_application_error(-20060,'Target identity must match an existing main development application in the configured workspace'); end if;
  select count(*) into l_count from apex_workspace_apex_users
   where workspace_id=l_config.workspace_id and upper(user_name)=l_lock_user
     and (upper(is_admin)='YES' or upper(is_application_developer)='YES') and upper(account_locked)='NO';
  if l_count<>1 then raise_application_error(-20060,'Lock owner must be an existing unlocked workspace developer or administrator'); end if;
  select count(*) into l_count from apxtm_operations where status='APPLYING';
  if l_count<>0 then raise_application_error(-20060,'An operation is applying; wait before changing recovery policy'); end if;
  update apxtm_config set modification_policy='DEVELOPMENT',lock_user=l_lock_user,
    updated_at=systimestamp where config_id=1;
  update apxtm_applications set allow_recovery='Y',updated_at=systimestamp where application_id=l_app_id;
  insert into apxtm_audit(application_id,actor,action,outcome,detail)
    values(l_app_id,l_owner,'ENABLE_RECOVERY','SUCCESS','Owner enabled development recovery for this target');
  commit;
  dbms_output.put_line('Development recovery enabled for the specified target. Workspace-wide Modify Other Applications authority requires separate owner review.');
end;
/
