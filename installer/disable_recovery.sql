-- SPDX-License-Identifier: Apache-2.0
-- Fail-safe owner action: disable future recovery requests for all targets.
-- This does not cancel an import already in progress or remove an APEX lock.
whenever oserror exit failure rollback
whenever sqlerror exit failure rollback
set define off verify off echo off serveroutput on sqlblanklines on

declare
  l_owner varchar2(300) := 'DB:'||upper(sys_context('USERENV','SESSION_USER'));
begin
  if apxtm_engine.actor<>l_owner
     or sys_context('USERENV','SESSION_USER')<>sys_context('USERENV','CURRENT_SCHEMA')
     or sys_context('USERENV','PROXY_USER') is not null then
    raise_application_error(-20060,'Disabling recovery requires a direct database owner session');
  end if;
  update apxtm_config set modification_policy='DISABLED',updated_at=systimestamp where config_id=1;
  update apxtm_applications set allow_recovery='N',updated_at=systimestamp;
  insert into apxtm_audit(actor,action,outcome,detail)
    values(l_owner,'DISABLE_RECOVERY','SUCCESS','Owner disabled future recovery requests for all targets');
  commit;
  dbms_output.put_line('Future recovery requests disabled. Review any already-running import separately.');
end;
/
