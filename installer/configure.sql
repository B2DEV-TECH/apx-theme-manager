-- SPDX-License-Identifier: Apache-2.0
-- Required binds: NUMBER :apxtm_workspace_id, NUMBER :apxtm_manager_app_id,
-- VARCHAR2(255) :apxtm_admin_user. Run only in a fresh direct owner session.
whenever oserror exit failure rollback
whenever sqlerror exit failure rollback
set define off verify off echo off serveroutput on sqlblanklines on

declare
  l_workspace_id number := :apxtm_workspace_id;
  l_manager_app_id number := :apxtm_manager_app_id;
  l_admin varchar2(255) := upper(trim(:apxtm_admin_user));
  l_owner varchar2(300) := 'DB:'||upper(sys_context('USERENV','SESSION_USER'));
  l_count number;
  l_config apxtm_config%rowtype;
begin
  if apxtm_engine.actor<>l_owner
     or sys_context('USERENV','SESSION_USER')<>sys_context('USERENV','CURRENT_SCHEMA')
     or sys_context('USERENV','PROXY_USER') is not null then
    raise_application_error(-20060,'Configuration requires a direct database owner session');
  end if;
  if l_workspace_id is null or l_workspace_id<=0 or l_workspace_id<>trunc(l_workspace_id)
     or l_manager_app_id is null or l_manager_app_id<=0 or l_manager_app_id<>trunc(l_manager_app_id)
     or l_admin is null then
    raise_application_error(-20060,'Set workspace, manager application and existing APEX administrator binds');
  end if;
  select * into l_config from apxtm_config where config_id=1 for update;
  if l_config.schema_version<>1 then raise_application_error(-20060,'Unsupported APXTM schema version'); end if;
  if (l_config.workspace_id is not null and l_config.workspace_id<>l_workspace_id)
     or (l_config.manager_app_id is not null and l_config.manager_app_id<>l_manager_app_id) then
    raise_application_error(-20060,'Rebinding an existing configuration to another workspace/application is refused');
  end if;
  select count(*) into l_count from apex_workspaces where workspace_id=l_workspace_id;
  if l_count<>1 then raise_application_error(-20060,'Workspace does not exist or is not visible to this schema'); end if;
  apex_util.set_security_group_id(l_workspace_id);
  select count(*) into l_count from apex_applications
   where workspace_id=l_workspace_id and application_id=l_manager_app_id
     and owner=sys_context('USERENV','SESSION_USER');
  if l_count<>1 then raise_application_error(-20060,'Manager must already exist in the requested workspace and use this parsing schema'); end if;
  select count(*) into l_count from apex_workspace_apex_users
   where workspace_id=l_workspace_id and upper(user_name)=l_admin
     and upper(is_admin)='YES' and upper(account_locked)='NO';
  if l_count<>1 then raise_application_error(-20060,'APEX administrator must be an existing unlocked account in this workspace'); end if;
  select count(*) into l_count from apxtm_applications where application_id=l_manager_app_id;
  if l_count<>0 then raise_application_error(-20060,'Manager application must not be in the target registry'); end if;
  select count(*) into l_count from apxtm_operations where status='APPLYING';
  if l_count<>0 then raise_application_error(-20060,'An operation is applying; stop before reconfiguration'); end if;
  update apxtm_config set workspace_id=l_workspace_id,manager_app_id=l_manager_app_id,
    modification_policy='DISABLED',lock_user=null,updated_at=systimestamp where config_id=1;
  update apxtm_applications set allow_recovery='N',updated_at=systimestamp;
  merge into apxtm_principals p using (select l_owner actor from dual union all select 'APEX:'||l_admin from dual) s
    on (p.actor=s.actor)
    when matched then update set p.permission_role='RESTORER',p.enabled='Y'
    when not matched then insert(actor,permission_role,enabled) values(s.actor,'RESTORER','Y');
  insert into apxtm_audit(actor,action,outcome,detail)
    values(l_owner,'CONFIGURE','SUCCESS','Owner configured workspace and manager; recovery disabled');
  commit;
  dbms_output.put_line('Configured; DB owner and named APEX administrator have RESTORER authority. Recovery is DISABLED.');
end;
/
