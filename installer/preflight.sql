-- SPDX-License-Identifier: Apache-2.0
-- Read-only prerequisite check. Connect directly as the dedicated parsing schema.
whenever oserror exit failure rollback
whenever sqlerror exit failure rollback
set define off verify off echo off serveroutput on sqlblanklines on

declare
  l_version varchar2(100);
  l_count number;
begin
  if sys_context('USERENV','SESSION_USER') <> sys_context('USERENV','CURRENT_SCHEMA')
     or sys_context('USERENV','PROXY_USER') is not null
     or sys_context('USERENV','SESSION_USER') in ('SYS','SYSTEM') then
    raise_application_error(-20060,'Connect directly as the dedicated parsing schema; do not change CURRENT_SCHEMA');
  end if;
  select version_no into l_version from apex_release;
  if l_version <> '26.2.0' then
    raise_application_error(-20060,'This release targets exact APEX 26.2.0; other versions have not been verified');
  end if;
  select count(*) into l_count from user_tab_privs
   where owner='SYS' and table_name='DBMS_CRYPTO'
     and grantee=sys_context('USERENV','SESSION_USER') and privilege='EXECUTE';
  if l_count=0 then
    raise_application_error(-20060,'A DBA must explicitly grant EXECUTE on SYS.DBMS_CRYPTO directly to this schema');
  end if;
  dbms_output.put_line('Owner: '||sys_context('USERENV','SESSION_USER'));
  dbms_output.put_line('APEX: '||l_version||'; DB compatibility: '||dbms_db_version.version||'.'||dbms_db_version.release);
  dbms_output.put_line('Preflight passed. This does not establish runtime compatibility or recovery safety.');
end;
/
