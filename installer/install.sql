-- SPDX-License-Identifier: Apache-2.0
-- Run from a fresh SQL*Plus/SQLcl connection as the dedicated parsing schema.
-- Start the client in the repository root; includes are relative to that directory.
-- No workspace/application creation, privileged grants or recovery enablement.
whenever oserror exit failure rollback
whenever sqlerror exit failure rollback
set define off verify off echo off serveroutput on sqlblanklines on

@installer/preflight.sql
@database/migrations/001_initial.sql
@database/packages/apxtm_parse.pks
@database/packages/apxtm_parse.pkb
@database/packages/apxtm_diff.pks
@database/packages/apxtm_diff.pkb
@database/packages/apxtm_engine.pks
@database/packages/apxtm_engine.pkb
@installer/verify.sql

prompt Core installation completed. Import the manager, then run configure.sql explicitly.
prompt A fresh installation has no principals or registered applications and recovery is DISABLED.
