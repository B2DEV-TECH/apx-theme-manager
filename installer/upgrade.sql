-- SPDX-License-Identifier: Apache-2.0
-- Version 1 only: recompile this release's packages without replacing stored data.
-- Stop manager use, disable recovery and back up APXTM data before running.
-- Start the client in the repository root; includes are relative to that directory.
whenever oserror exit failure rollback
whenever sqlerror exit failure rollback
set define off verify off echo off serveroutput on sqlblanklines on

declare
  l_version number;
  l_policy varchar2(20);
  l_count number;
begin
  select schema_version,modification_policy into l_version,l_policy from apxtm_config where config_id=1;
  if l_version<>1 then raise_application_error(-20060,'No migration is provided for this schema version'); end if;
  if l_policy<>'DISABLED' then raise_application_error(-20060,'Run disable_recovery.sql before maintenance'); end if;
  select count(*) into l_count from apxtm_operations where status='APPLYING';
  if l_count<>0 then raise_application_error(-20060,'An operation is applying; do not upgrade'); end if;
end;
/
@installer/install.sql
prompt Version 1 package reinstall completed; manager application import is a separate reviewed action.
