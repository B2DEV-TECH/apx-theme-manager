-- SPDX-License-Identifier: Apache-2.0
-- Required NUMBER bind: :apxtm_target_app_id. Registration never enables recovery.
whenever oserror exit failure rollback
whenever sqlerror exit failure rollback
set define off verify off echo off serveroutput on sqlblanklines on

declare
  l_app_id number := :apxtm_target_app_id;
begin
  if sys_context('USERENV','SESSION_USER')<>sys_context('USERENV','CURRENT_SCHEMA')
     or sys_context('USERENV','PROXY_USER') is not null then
    raise_application_error(-20060,'Registration requires a direct parsing-schema owner session');
  end if;
  if l_app_id is null or l_app_id<=0 or l_app_id<>trunc(l_app_id) then
    raise_application_error(-20060,'Set a positive integer target application ID bind');
  end if;
  apxtm_engine.register_application(l_app_id);
  commit;
  dbms_output.put_line('Application registered. Inspect its registry row before separately enabling recovery.');
end;
/
