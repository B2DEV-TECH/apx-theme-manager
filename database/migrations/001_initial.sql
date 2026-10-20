declare
  n number;
  v number;
begin
  select count(*) into n from user_tables where table_name='APXTM_CONFIG';
  if n=1 then
    execute immediate 'select schema_version from apxtm_config where config_id=1' into v;
    if v!=1 then raise_application_error(-20050,'Unsupported schema version; use an explicit migration'); end if;
    return;
  end if;
  select count(*) into n from user_objects where object_name like 'APXTM\_%' escape '\' and object_type='TABLE';
  if n>0 then raise_application_error(-20050,'Existing APXTM objects: inspect before installation'); end if;
  execute immediate q'~create table apxtm_config (
    config_id number default 1 primary key check(config_id=1),
    schema_version number not null, workspace_id number,
    manager_app_id number, modification_policy varchar2(20) default 'DISABLED' not null
      check(modification_policy in ('DISABLED','DEVELOPMENT')),
    lock_user varchar2(255), created_at timestamp with time zone default systimestamp not null,
    updated_at timestamp with time zone default systimestamp not null)~';
  execute immediate q'~insert into apxtm_config(config_id,schema_version) values(1,1)~';
  execute immediate q'~create table apxtm_principals (
    actor varchar2(300) primary key,
    permission_role varchar2(20) not null check(permission_role in ('READER','RECOVERER','RESTORER')),
    enabled char(1) default 'Y' not null check(enabled in ('Y','N')),
    created_at timestamp with time zone default systimestamp not null)~';
  execute immediate q'~create table apxtm_applications (
    application_id number primary key,workspace_id number not null,
    application_name varchar2(255) not null,application_alias varchar2(255) not null,
    parsing_schema varchar2(128) not null,
    allow_recovery char(1) default 'N' not null check(allow_recovery in ('Y','N')),
    enabled char(1) default 'Y' not null check(enabled in ('Y','N')),
    created_by varchar2(300) not null,
    created_at timestamp with time zone default systimestamp not null,
    updated_at timestamp with time zone default systimestamp not null)~';
  execute immediate q'~create table apxtm_artifacts (
    artifact_id number generated always as identity primary key,
    application_id number not null references apxtm_applications(application_id),
    workspace_id number not null, source_hash varchar2(64) not null,
    archive_hash varchar2(64) not null, source_name varchar2(255) not null,
    source_characters number not null, component_count number not null,
    apex_version varchar2(40) not null, archive blob not null,
    created_at timestamp with time zone default systimestamp not null,
    constraint apxtm_artifact_uk unique(application_id,source_hash))~';
  execute immediate q'~create table apxtm_snapshots (
    snapshot_id number generated always as identity primary key,
    artifact_id number not null references apxtm_artifacts(artifact_id),
    snapshot_name varchar2(255) not null,
    snapshot_kind varchar2(20) not null check(snapshot_kind in ('BASELINE','CURRENT','BACKUP')),
    created_by varchar2(300) not null,
    created_at timestamp with time zone default systimestamp not null)~';
  execute immediate q'~create table apxtm_comparisons (
    comparison_id number generated always as identity primary key,
    baseline_snapshot_id number not null references apxtm_snapshots(snapshot_id),
    current_snapshot_id number not null references apxtm_snapshots(snapshot_id),
    application_id number not null references apxtm_applications(application_id),
    status varchar2(20) default 'READY' not null check(status in ('READY','STALE','RECOVERED','FAILED')),
    created_by varchar2(300) not null,
    created_at timestamp with time zone default systimestamp not null)~';
  execute immediate q'~create table apxtm_differences (
    difference_id number generated always as identity primary key,
    comparison_id number not null references apxtm_comparisons(comparison_id),
    component_key varchar2(512) not null,component_type varchar2(30) not null,
    component_name varchar2(255) not null,page_id number not null,
    property_name varchar2(128) not null,baseline_value varchar2(4000),current_value varchar2(4000),
    classification varchar2(20) not null check(classification in
      ('UNCHANGED','CHANGED','ADDED','DROPPED','NO_MATCH','AMBIGUOUS','UNSUPPORTED','CONFLICT')),
    eligible char(1) default 'N' not null check(eligible in ('Y','N')),
    reason varchar2(500) not null,
    outcome varchar2(20) default 'PENDING' not null check(outcome in ('PENDING','FIXED','FAILED')),
    created_at timestamp with time zone default systimestamp not null,
    constraint apxtm_diff_uk unique(comparison_id,component_key,property_name))~';
  execute immediate q'~create index apxtm_diff_filter_ix on apxtm_differences(comparison_id,classification,eligible)~';
  execute immediate q'~create table apxtm_operations (
    operation_id number generated always as identity primary key,
    application_id number not null references apxtm_applications(application_id),
    comparison_id number references apxtm_comparisons(comparison_id),
    operation_kind varchar2(20) not null check(operation_kind in ('RECOVER','RESTORE')),
    expected_artifact_id number not null references apxtm_artifacts(artifact_id),
    proposed_artifact_id number not null references apxtm_artifacts(artifact_id),
    backup_snapshot_id number references apxtm_snapshots(snapshot_id),
    selection clob not null check(selection is json),token_hash varchar2(64) not null,
    status varchar2(20) default 'PREVIEW' not null check(status in
      ('PREVIEW','APPLYING','VERIFIED','FAILED','INVALIDATED')),
    selected_count number not null,created_by varchar2(300) not null,
    error_code number,result_message varchar2(1000),
    created_at timestamp with time zone default systimestamp not null,
    updated_at timestamp with time zone default systimestamp not null,
    expires_at timestamp with time zone default systimestamp+interval '15' minute not null)~';
  execute immediate q'~create unique index apxtm_single_apply_uk on apxtm_operations
    (case when status='APPLYING' then application_id end)~';
  execute immediate q'~create table apxtm_audit (
    event_id number generated always as identity primary key,
    application_id number,operation_id number references apxtm_operations(operation_id),
    actor varchar2(300) not null,action varchar2(40) not null,outcome varchar2(20) not null,
    error_code number,detail varchar2(1000),
    created_at timestamp with time zone default systimestamp not null)~';
  commit;
end;
/
create or replace trigger apxtm_snapshot_immutable
before update on apxtm_snapshots
begin raise_application_error(-20051,'Snapshots are immutable'); end;
/
create or replace trigger apxtm_artifact_immutable
before update on apxtm_artifacts
begin raise_application_error(-20051,'Export artifacts are immutable'); end;
/
create or replace trigger apxtm_audit_immutable
before update or delete on apxtm_audit
begin raise_application_error(-20051,'Audit events are append-only'); end;
/
