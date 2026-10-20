-- SPDX-License-Identifier: Apache-2.0
-- Required NUMBER binds: :apxtm_workspace_id, :apxtm_manager_app_id.
-- New manager installation only. Existing applications are never overwritten.
-- Start the client in the repository root; includes are relative to that directory.
whenever oserror exit failure rollback
whenever sqlerror exit failure rollback
set define off verify off echo off serveroutput on sqlblanklines on

@installer/preflight.sql
declare
  l_workspace_id number := :apxtm_workspace_id;
  l_app_id number := :apxtm_manager_app_id;
  l_count number;
begin
  if l_workspace_id is null or l_workspace_id<=0 or l_workspace_id<>trunc(l_workspace_id)
     or l_app_id is null or l_app_id<=0 or l_app_id<>trunc(l_app_id) then
    raise_application_error(-20060,'Set positive integer workspace and manager application ID binds');
  end if;
  select count(*) into l_count from apex_workspace_schemas
   where workspace_id=l_workspace_id and schema=sys_context('USERENV','SESSION_USER');
  if l_count<>1 then raise_application_error(-20060,'Workspace does not exist or the current schema is not assigned to it'); end if;
  apex_util.set_security_group_id(l_workspace_id);
  select count(*) into l_count from apex_applications where application_id=l_app_id;
  if l_count<>0 then raise_application_error(-20060,'Application ID is already in use; overwrite is refused'); end if;
  apex_application_install.clear_all;
  apex_application_install.set_workspace_id(l_workspace_id);
  apex_application_install.set_schema(sys_context('USERENV','SESSION_USER'));
  apex_application_install.set_application_id(l_app_id);
  apex_application_install.generate_offset;
  apex_application_install.set_auto_install_sup_obj(false);
end;
/
@apex/f104.sql
set define off verify off echo off serveroutput on
declare
  l_count number;
begin
  select count(*) into l_count from apex_applications
   where workspace_id=:apxtm_workspace_id and application_id=:apxtm_manager_app_id
     and owner=sys_context('USERENV','SESSION_USER');
  if l_count<>1 then raise_application_error(-20060,'Imported manager identity does not match the requested workspace/schema/application'); end if;
  apex_application_install.clear_all;
  dbms_output.put_line('Manager imported. Configure access explicitly with configure.sql.');
end;
/
