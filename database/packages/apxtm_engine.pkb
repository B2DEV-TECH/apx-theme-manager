create or replace package body apxtm_engine as
  procedure deny(p_message varchar2 default 'Operation is not authorized for this target') is
  begin raise_application_error(-20020,p_message); end;

  function actor return varchar2 is
  begin
    if nvl(apex_application.g_flow_id,0)!=0 then
      return 'APEX:'||upper(apex_application.g_user);
    end if;
    return 'DB:'||upper(sys_context('USERENV','SESSION_USER'));
  end;

  function has_permission(p_permission varchar2 default 'READ') return boolean is
    r apxtm_principals.permission_role%type;
    c apxtm_config%rowtype;
  begin
    if p_permission is null or p_permission not in ('READ','RECOVER','RESTORE') then return false; end if;
    select * into c from apxtm_config where config_id=1;
    if c.workspace_id is null or c.manager_app_id is null then return false; end if;
    if nvl(apex_application.g_flow_id,0)!=0 then
      if apex_application.g_flow_id!=c.manager_app_id
        or upper(nvl(apex_application.g_user,'NOBODY')) in ('NOBODY','APEX_PUBLIC_USER')
        or to_number(nvl(sys_context('APEX$SESSION','WORKSPACE_ID'),'0'))!=c.workspace_id then return false; end if;
    elsif upper(sys_context('USERENV','SESSION_USER'))!=upper(sys_context('USERENV','CURRENT_USER')) then return false;
    end if;
    select permission_role into r from apxtm_principals where actor=apxtm_engine.actor and enabled='Y';
    return p_permission='READ' or (p_permission='RECOVER' and r in ('RECOVERER','RESTORER'))
      or (p_permission='RESTORE' and r='RESTORER');
  exception when no_data_found then return false;
  end;

  procedure assert_access(p_application_id number,p_permission varchar2 default 'READ') is
    c apxtm_config%rowtype;
    r apxtm_applications%rowtype;
    a apex_applications%rowtype;
    n number;
    version varchar2(40);
  begin
    if not has_permission(p_permission) then deny; end if;
    select * into c from apxtm_config where config_id=1;
    select * into r from apxtm_applications where application_id=p_application_id and enabled='Y';
    if r.workspace_id!=c.workspace_id or p_application_id=c.manager_app_id then deny; end if;
    select * into a from apex_applications where application_id=p_application_id and workspace_id=c.workspace_id;
    if upper(a.owner)!=upper(r.parsing_schema) or upper(a.owner)!=upper(sys_context('USERENV','CURRENT_USER'))
      or a.alias!=r.application_alias then deny('Registered application identity has changed'); end if;
    if p_permission in ('RECOVER','RESTORE') then
      select version_no into version from apex_release;
      if version!='26.2.0' then deny('Recovery is enabled only for the tested APEX 26.2.0 format'); end if;
      if c.modification_policy!='DEVELOPMENT' or r.allow_recovery!='Y' or c.lock_user is null
        or a.build_status!='Run and Develop' or a.working_copy_name is not null then
        deny('Development recovery policy is not enabled for this application');
      end if;
      select count(*) into n from apex_workspace_apex_users where workspace_id=c.workspace_id
        and upper(user_name)=upper(c.lock_user) and (is_admin='Yes' or is_application_developer='Yes');
      if n!=1 then deny('Configured application lock owner is not a workspace developer'); end if;
    end if;
  exception when no_data_found then deny;
  end;

  function allowed(p_application_id number,p_permission varchar2 default 'READ') return number is
  begin assert_access(p_application_id,p_permission); return 1;
  exception when others then return 0; end;

  procedure event(p_app number,p_action varchar2,p_outcome varchar2,p_detail varchar2 default null,
    p_operation number default null,p_code number default null) is
  begin
    insert into apxtm_audit(application_id,operation_id,actor,action,outcome,detail,error_code)
    values(p_app,p_operation,actor,p_action,p_outcome,substr(p_detail,1,1000),p_code);
  end;

  procedure free_files(p_files in out nocopy apex_t_export_files) is
  begin
    if p_files is not null then
      for i in 1..p_files.count loop
        if dbms_lob.istemporary(p_files(i).contents)=1 then dbms_lob.freetemporary(p_files(i).contents); end if;
        if dbms_lob.istemporary(p_files(i).contents_blob)=1 then dbms_lob.freetemporary(p_files(i).contents_blob); end if;
      end loop;
    end if;
  end;

  function source_hash(p_source clob) return varchar2 is
  begin return rawtohex(dbms_crypto.hash(p_source,dbms_crypto.hash_sh256)); end;

  function token_hash(p_token varchar2) return varchar2 is
  begin return rawtohex(dbms_crypto.hash(utl_i18n.string_to_raw(p_token,'AL32UTF8'),dbms_crypto.hash_sh256)); end;

  function live_export(p_app number) return apex_t_export_files is
    pragma autonomous_transaction;
    f apex_t_export_files;
    ws number;
    version varchar2(40);
  begin
    select workspace_id into ws from apxtm_applications where application_id=p_app;
    select version_no into version from apex_release;
    if version!='26.2.0' then raise_application_error(-20025,'Untested APEX export format; this build requires 26.2.0'); end if;
    apex_util.set_security_group_id(ws);
    f:=apex_export.get_application(p_application_id=>p_app,p_type=>'SQL',p_split=>false,
      p_with_date=>false,p_with_original_ids=>false,p_with_no_subscriptions=>false,
      p_with_audit_info=>null,p_with_supporting_objects=>'N',p_with_acl_assignments=>false);
    rollback;
    return f;
  exception when others then rollback;free_files(f);raise;
  end;

  procedure check_source(p_files apex_t_export_files,p_app number) is
    info apex_application_install.t_file_info;
    r apxtm_applications%rowtype;
    components json_array_t;
    pages number:=0;themes number:=0;o json_object_t;
  begin
    select * into r from apxtm_applications where application_id=p_app;
    if p_files is null or p_files.count!=1 or p_files(1).contents is null
      or not regexp_like(p_files(1).name,'^f[0-9]+[.]sql$') then
      raise_application_error(-20026,'Expected one complete SQL application export');
    end if;
    if dbms_lob.instr(p_files(1).contents,chr(13))>0 then raise_application_error(-20026,'Unsupported non-LF export');end if;
    apex_application_install.clear_all;
    info:=apex_application_install.get_info(p_files);
    if info.app_id!=p_app or info.workspace_id!=r.workspace_id or upper(info.app_owner)!=upper(r.parsing_schema)
      or info.app_id is null or info.workspace_id is null or info.app_owner is null then
      raise_application_error(-20026,'Export identity does not match the registered application');
    end if;
    components:=apxtm_parse.parse(p_files(1).contents);
    for i in 0..components.get_size-1 loop
      o:=treat(components.get(i) as json_object_t);
      if o.get_string('kind')='PAGE' then pages:=pages+1;end if;
      if o.get_string('kind')='THEME' then themes:=themes+1;end if;
    end loop;
    if pages=0 or themes=0 then raise_application_error(-20026,'Export is missing pages or theme definitions');end if;
    -- Both markers are generated export envelope constructs, not callable APIs.
    if not regexp_like(p_files(1).contents,'wwv_flow_imp[.]import_begin[[:space:]]*[(]')
      or not regexp_like(p_files(1).contents,'wwv_flow_imp[.]import_end[[:space:]]*[(]') then
      raise_application_error(-20026,'Application export envelope is incomplete');
    end if;
  end;

  function artifact_files(p_artifact number) return apex_t_export_files is
    r apxtm_artifacts%rowtype;
    f apex_t_export_files;
  begin
    select * into r from apxtm_artifacts where artifact_id=p_artifact;
    if rawtohex(dbms_crypto.hash(r.archive,dbms_crypto.hash_sh256))!=r.archive_hash then
      raise_application_error(-20027,'Snapshot archive integrity failed');end if;
    f:=apex_export.unzip(r.archive);
    if f.count!=1 or f(1).name!=r.source_name or f(1).contents is null
      or dbms_lob.getlength(f(1).contents)!=r.source_characters or source_hash(f(1).contents)!=r.source_hash then
      raise_application_error(-20027,'Snapshot source integrity failed');end if;
    check_source(f,r.application_id);
    return f;
  exception when others then free_files(f);raise;
  end;

  function put_artifact(p_app number,p_files apex_t_export_files) return number is
    h varchar2(64); z blob; id number; ws number; version varchar2(40);
    parsed json_array_t; verified apex_t_export_files;component_count number;
  begin
    check_source(p_files,p_app);h:=source_hash(p_files(1).contents);
    begin
      select artifact_id into id from apxtm_artifacts where application_id=p_app and source_hash=h;
      verified:=artifact_files(id);free_files(verified);return id;
    exception when no_data_found then null;end;
    z:=apex_export.zip(p_files); verified:=apex_export.unzip(z);
    if verified.count!=1 or source_hash(verified(1).contents)!=h then raise_application_error(-20027,'Export ZIP round trip failed');end if;
    free_files(verified);
    parsed:=apxtm_parse.parse(p_files(1).contents);component_count:=parsed.get_size;
    select workspace_id into ws from apxtm_applications where application_id=p_app;
    select version_no into version from apex_release;
    insert into apxtm_artifacts(application_id,workspace_id,source_hash,archive_hash,source_name,
      source_characters,component_count,apex_version,archive)
    values(p_app,ws,h,rawtohex(dbms_crypto.hash(z,dbms_crypto.hash_sh256)),p_files(1).name,
      dbms_lob.getlength(p_files(1).contents),component_count,version,z) returning artifact_id into id;
    if dbms_lob.istemporary(z)=1 then dbms_lob.freetemporary(z);end if;
    verified:=artifact_files(id);free_files(verified);return id;
  exception when others then
    free_files(verified);if dbms_lob.istemporary(z)=1 then dbms_lob.freetemporary(z);end if;raise;
  end;

  function save_snapshot(p_app number,p_files apex_t_export_files,p_name varchar2,p_kind varchar2) return number is
    art number; id number;
  begin
    if p_kind is null or p_kind not in ('BASELINE','CURRENT','BACKUP') then raise_application_error(-20026,'Invalid snapshot kind');end if;
    art:=put_artifact(p_app,p_files);
    insert into apxtm_snapshots(artifact_id,snapshot_name,snapshot_kind,created_by)
    values(art,substr(nvl(p_name,p_kind||' '||to_char(systimestamp,'YYYY-MM-DD HH24:MI:SS TZH:TZM')),1,255),p_kind,actor)
    returning snapshot_id into id;
    return id;
  end;

  procedure register_application(p_application_id number) is
    pragma autonomous_transaction;
    c apxtm_config%rowtype;a apex_applications%rowtype;
  begin
    if nvl(apex_application.g_flow_id,0)!=0 or upper(sys_context('USERENV','SESSION_USER'))!=upper(sys_context('USERENV','CURRENT_USER')) then deny;end if;
    select * into c from apxtm_config where config_id=1;
    select * into a from apex_applications where application_id=p_application_id and workspace_id=c.workspace_id;
    if c.manager_app_id is null or p_application_id=c.manager_app_id or upper(a.owner)!=upper(sys_context('USERENV','CURRENT_USER')) then deny;end if;
    insert into apxtm_applications(application_id,workspace_id,application_name,application_alias,parsing_schema,created_by)
    values(a.application_id,a.workspace_id,a.application_name,a.alias,a.owner,actor);
    event(p_application_id,'REGISTER','SUCCESS','Registered read-only; recovery remains disabled.');commit;
  exception when others then rollback;raise;
  end;

  function take_snapshot(p_application_id number,p_name varchar2 default null,p_kind varchar2 default 'BASELINE') return number is
    pragma autonomous_transaction;
    f apex_t_export_files; id number; code number;
  begin
    assert_access(p_application_id);f:=live_export(p_application_id);
    id:=save_snapshot(p_application_id,f,p_name,p_kind);
    event(p_application_id,'SNAPSHOT','VERIFIED','Snapshot '||id||' persisted and integrity-checked.');commit;free_files(f);return id;
  exception when others then code:=sqlcode;rollback;free_files(f);event(p_application_id,'SNAPSHOT','FAILED','Snapshot was not recorded as successful.',null,code);commit;raise;
  end;

  function validate_snapshot(p_snapshot_id number) return boolean is
    art number;app number;f apex_t_export_files;
  begin
    select s.artifact_id,a.application_id into art,app from apxtm_snapshots s join apxtm_artifacts a on a.artifact_id=s.artifact_id where s.snapshot_id=p_snapshot_id;
    assert_access(app);f:=artifact_files(art);free_files(f);return true;
  exception when others then free_files(f);raise;
  end;

  function snapshot_zip(p_snapshot_id number) return blob is
    z blob;ok boolean;
  begin
    ok:=validate_snapshot(p_snapshot_id);
    select a.archive into z from apxtm_snapshots s join apxtm_artifacts a on a.artifact_id=s.artifact_id where s.snapshot_id=p_snapshot_id;
    return z;
  end;

  function compare(p_snapshot_id number) return number is
    pragma autonomous_transaction;
    art number;app number;current_id number;current_art number;id number;
    b apex_t_export_files;c apex_t_export_files;diffs json_array_t;o json_object_t;code number;d apxtm_differences%rowtype;
  begin
    select s.artifact_id,a.application_id into art,app from apxtm_snapshots s join apxtm_artifacts a on a.artifact_id=s.artifact_id where s.snapshot_id=p_snapshot_id;
    assert_access(app);b:=artifact_files(art);c:=live_export(app);
    current_id:=save_snapshot(app,c,'Comparison capture','CURRENT');
    diffs:=apxtm_diff.compare_sources(b(1).contents,c(1).contents);
    insert into apxtm_comparisons(baseline_snapshot_id,current_snapshot_id,application_id,created_by)
    values(p_snapshot_id,current_id,app,actor) returning comparison_id into id;
    for i in 0..diffs.get_size-1 loop
      o:=treat(diffs.get(i) as json_object_t);
      d.component_key:=o.get_string('key');d.component_type:=o.get_string('kind');
      d.component_name:=substr(o.get_string('name'),1,255);d.page_id:=o.get_number('page');
      d.property_name:=o.get_string('property');d.baseline_value:=o.get_string('baseline');
      d.current_value:=o.get_string('current');d.classification:=o.get_string('classification');
      d.eligible:=o.get_string('eligible');d.reason:=o.get_string('reason');
      insert into apxtm_differences(comparison_id,component_key,component_type,component_name,page_id,
        property_name,baseline_value,current_value,classification,eligible,reason)
      values(id,d.component_key,d.component_type,d.component_name,d.page_id,
        d.property_name,d.baseline_value,d.current_value,d.classification,d.eligible,d.reason);
    end loop;
    event(app,'COMPARE','SUCCESS','Comparison '||id||' bound to exact current export.');commit;
    free_files(b);free_files(c);return id;
  exception when others then code:=sqlcode;rollback;free_files(b);free_files(c);event(app,'COMPARE','FAILED','Comparison failed.',null,code);commit;raise;
  end;

  procedure preview(p_comparison_id number,p_difference_ids varchar2 default null,p_operation_id out number,p_token out varchar2) is
    pragma autonomous_transaction;
    r apxtm_comparisons%rowtype;expected number;proposed number;h varchar2(64);
    f apex_t_export_files;changes json_array_t:=json_array_t();o json_object_t;patched clob;code number;
    requested apex_t_varchar2;selection clob;selected_count number;
  begin
    select * into r from apxtm_comparisons where comparison_id=p_comparison_id;
    assert_access(r.application_id,'RECOVER');
    if r.status!='READY' then raise_application_error(-20024,'Comparison is no longer available; compare again');end if;
    if p_difference_ids is not null and not regexp_like(p_difference_ids,'^[0-9]+(:[0-9]+)*$') then raise_application_error(-20026,'Invalid selection');end if;
    select s.artifact_id,a.source_hash into expected,h from apxtm_snapshots s join apxtm_artifacts a on a.artifact_id=s.artifact_id where s.snapshot_id=r.current_snapshot_id;
    f:=live_export(r.application_id);
    if source_hash(f(1).contents)!=h then
      update apxtm_comparisons set status='STALE' where comparison_id=p_comparison_id;commit;
      raise_application_error(-20024,'Application changed after comparison; compare again');end if;
    for d in (select * from apxtm_differences where comparison_id=p_comparison_id
      and ((p_difference_ids is null and eligible='Y') or (p_difference_ids is not null and instr(':'||p_difference_ids||':',':'||to_char(difference_id)||':')>0)) order by difference_id) loop
      if d.eligible!='Y' or d.classification!='CHANGED' then raise_application_error(-20026,'Selection contains an ineligible difference');end if;
      o:=json_object_t();o.put('key',d.component_key);o.put('property',d.property_name);
      o.put('expected',d.current_value);o.put('value',d.baseline_value);o.put('difference_id',d.difference_id);changes.append(o);
    end loop;
    if p_difference_ids is not null then requested:=apex_string.split(p_difference_ids,':');
      if requested.count!=changes.get_size then raise_application_error(-20026,'Selection contains duplicates, missing IDs or another comparison');end if;end if;
    patched:=apxtm_parse.patch(f(1).contents,changes);
    free_files(f);f:=apex_t_export_files(apex_t_export_file(name=>'f'||r.application_id||'.sql',contents=>patched));
    proposed:=put_artifact(r.application_id,f);p_token:=rawtohex(dbms_crypto.randombytes(32));h:=token_hash(p_token);
    selection:=changes.to_clob;selected_count:=changes.get_size;
    insert into apxtm_operations(application_id,comparison_id,operation_kind,expected_artifact_id,proposed_artifact_id,selection,token_hash,selected_count,created_by)
    values(r.application_id,p_comparison_id,'RECOVER',expected,proposed,selection,h,selected_count,actor)
    returning operation_id into p_operation_id;
    event(r.application_id,'PREVIEW','SUCCESS','Selected '||changes.get_size||' scalar changes; no application modification.',p_operation_id);commit;free_files(f);
  exception when others then code:=sqlcode;rollback;free_files(f);event(r.application_id,'PREVIEW','FAILED','Preview rejected or failed.',null,code);commit;raise;
  end;

  procedure preview_restore(p_snapshot_id number,p_operation_id out number,p_token out varchar2) is
    pragma autonomous_transaction;
    app number;proposed number;expected number;f apex_t_export_files;b apex_t_export_files;code number;h varchar2(64);
  begin
    select a.application_id,s.artifact_id into app,proposed from apxtm_snapshots s join apxtm_artifacts a on a.artifact_id=s.artifact_id where s.snapshot_id=p_snapshot_id;
    assert_access(app,'RESTORE');b:=artifact_files(proposed);f:=live_export(app);expected:=put_artifact(app,f);
    p_token:=rawtohex(dbms_crypto.randombytes(32));h:=token_hash(p_token);
    insert into apxtm_operations(application_id,operation_kind,expected_artifact_id,proposed_artifact_id,selection,token_hash,selected_count,created_by)
    values(app,'RESTORE',expected,proposed,'[]',h,0,actor) returning operation_id into p_operation_id;
    event(app,'RESTORE_PREVIEW','SUCCESS','Full definition restore preview. Runtime data is not included.',p_operation_id);commit;free_files(f);free_files(b);
  exception when others then code:=sqlcode;rollback;free_files(f);free_files(b);event(app,'RESTORE_PREVIEW','FAILED','Restore preview rejected.',null,code);commit;raise;
  end;

  procedure apply(p_operation_id number,p_token varchar2,p_confirmation varchar2) is
    pragma autonomous_transaction;
    r apxtm_operations%rowtype;c apxtm_config%rowtype;a apxtm_applications%rowtype;
    current_files apex_t_export_files;proposed_files apex_t_export_files;after_files apex_t_export_files;
    expected_hash varchar2(64);proposed_hash varchar2(64);changes json_array_t;regenerated clob;
    backup number;locked boolean:=false;claimed boolean:=false;code number;existing_lock number;

    procedure release_lock is
    begin
      if locked then
        apex_application_admin.unlock_application(p_application_id=>r.application_id,p_unlock_as_user=>c.lock_user);
        commit;locked:=false;
      end if;
    exception when others then
      event(r.application_id,'UNLOCK','FAILED','An application lock may remain; a workspace administrator must inspect it.',p_operation_id,sqlcode);commit;
    end;
  begin
    select * into r from apxtm_operations where operation_id=p_operation_id;
    assert_access(r.application_id,case r.operation_kind when 'RESTORE' then 'RESTORE' else 'RECOVER' end);
    if r.created_by!=actor or r.status!='PREVIEW' or r.expires_at<systimestamp
      or p_token is null or token_hash(p_token)!=r.token_hash then raise_application_error(-20028,'Expired, consumed or unauthorized operation token');end if;
    if p_confirmation!=(case r.operation_kind when 'RESTORE' then 'RESTORE ' else 'APPLY ' end)||r.application_id
      or p_confirmation is null then raise_application_error(-20028,'Typed application confirmation does not match');end if;
    select * into c from apxtm_config where config_id=1;
    select * into a from apxtm_applications where application_id=r.application_id;
    update apxtm_operations set status='APPLYING',updated_at=systimestamp where operation_id=p_operation_id and status='PREVIEW';
    if sql%rowcount!=1 then raise_application_error(-20028,'Operation has already been claimed');end if;
    commit;claimed:=true;
    -- Locking protects against other App Builder developers. It cannot constrain
    -- privileged database/script writers; use a coordinated maintenance window.
    select count(*) into existing_lock from apex_applications where application_id=r.application_id and locked_by is not null;
    if existing_lock>0 then raise_application_error(-20029,'Application already has a developer lock');end if;
    apex_application_admin.lock_application(p_application_id=>r.application_id,p_lock_as_user=>c.lock_user,p_lock_comment=>'APEX Theme Manager operation '||p_operation_id);
    commit;locked:=true;
    select source_hash into expected_hash from apxtm_artifacts where artifact_id=r.expected_artifact_id;
    select source_hash into proposed_hash from apxtm_artifacts where artifact_id=r.proposed_artifact_id;
    current_files:=live_export(r.application_id);
    if source_hash(current_files(1).contents)!=expected_hash then
      update apxtm_operations set status='INVALIDATED',result_message='Application changed; compare again.' where operation_id=p_operation_id;
      update apxtm_comparisons set status='STALE' where comparison_id=r.comparison_id;commit;
      raise_application_error(-20024,'Application changed after preview; compare again');end if;
    backup:=save_snapshot(r.application_id,current_files,'Before operation '||p_operation_id,'BACKUP');
    update apxtm_operations set backup_snapshot_id=backup,result_message='Verified backup persisted before import.',updated_at=systimestamp where operation_id=p_operation_id;
    event(r.application_id,'BACKUP','VERIFIED','Pre-operation snapshot '||backup,p_operation_id);commit;
    proposed_files:=artifact_files(r.proposed_artifact_id);changes:=json_array_t(r.selection);
    if r.operation_kind='RECOVER' then
      regenerated:=apxtm_parse.patch(current_files(1).contents,changes);
      if source_hash(regenerated)!=proposed_hash then raise_application_error(-20027,'Proposed artifact is not the approved allowlisted patch');end if;
      dbms_lob.freetemporary(regenerated);
    end if;
    free_files(current_files);current_files:=live_export(r.application_id);
    if source_hash(current_files(1).contents)!=expected_hash then raise_application_error(-20024,'Application changed during recovery preparation');end if;
    assert_access(r.application_id,case r.operation_kind when 'RESTORE' then 'RESTORE' else 'RECOVER' end);
    check_source(proposed_files,r.application_id);
    apex_application_install.clear_all;
    apex_application_install.set_workspace_id(a.workspace_id);
    apex_application_install.set_application_id(r.application_id);
    apex_application_install.set_schema(a.parsing_schema);
    apex_application_install.set_auto_install_sup_obj(false);
    -- Capture uses current IDs and the generated export's own offset context.
    -- No new ID or guessed offset is generated when overwriting the same app.
    apex_application_install.install(p_source=>proposed_files,p_overwrite_existing=>true);
    -- INSTALL leaves metadata DML pending on the tested release. This autonomous
    -- operation owns the import, so complete that boundary before independent
    -- export. This does not commit the caller or promise atomic rollback.
    commit;
    after_files:=live_export(r.application_id);
    if source_hash(after_files(1).contents)!=proposed_hash then
      raise_application_error(-20030,'Post-import export does not exactly match the approved artifact; inspect the backup and audit');end if;
    if r.operation_kind='RECOVER' then
      update apxtm_differences set outcome='FIXED' where comparison_id=r.comparison_id and difference_id in
        (select difference_id from json_table(r.selection,'$[*]' columns(difference_id number path '$.difference_id')));
      update apxtm_comparisons set status='RECOVERED' where comparison_id=r.comparison_id;
    end if;
    update apxtm_operations set status='VERIFIED',result_message='Independent re-export exactly matches the approved source.',updated_at=systimestamp where operation_id=p_operation_id;
    event(r.application_id,'APPLY','VERIFIED','Application identity and complete definition fingerprint verified.',p_operation_id);commit;
    release_lock;free_files(current_files);free_files(proposed_files);free_files(after_files);
  exception when others then
    code:=sqlcode;rollback;
    if claimed then
      update apxtm_operations set status='FAILED',error_code=code,updated_at=systimestamp,
        result_message='Operation failed. Import may be partial; inspect the verified backup and application.'
      where operation_id=p_operation_id and status='APPLYING';
      if r.operation_kind='RECOVER' then update apxtm_differences set outcome='FAILED' where comparison_id=r.comparison_id
        and difference_id in(select difference_id from json_table(r.selection,'$[*]' columns(difference_id number path '$.difference_id')));end if;
      commit;
    end if;
    event(r.application_id,'APPLY','FAILED','Request rejected or recovery failed; no atomic rollback is promised.',case when claimed then p_operation_id end,code);commit;
    release_lock;free_files(current_files);free_files(proposed_files);free_files(after_files);
    if dbms_lob.istemporary(regenerated)=1 then dbms_lob.freetemporary(regenerated);end if;
    raise;
  end;

  function operation_zip(p_operation_id number) return blob is
    r apxtm_operations%rowtype;z blob;f apex_t_export_files;
  begin
    select * into r from apxtm_operations where operation_id=p_operation_id;assert_access(r.application_id);
    f:=artifact_files(r.proposed_artifact_id);free_files(f);
    select archive into z from apxtm_artifacts where artifact_id=r.proposed_artifact_id;return z;
  end;

  procedure retire_snapshot(p_snapshot_id number,p_confirmation varchar2) is
    pragma autonomous_transaction;
    art number;app number;
  begin
    select s.artifact_id,a.application_id into art,app from apxtm_snapshots s join apxtm_artifacts a on a.artifact_id=s.artifact_id where s.snapshot_id=p_snapshot_id;
    assert_access(app,'RESTORE');
    if p_confirmation is null or p_confirmation!='DELETE '||p_snapshot_id then raise_application_error(-20028,'Snapshot deletion confirmation does not match');end if;
    delete from apxtm_snapshots where snapshot_id=p_snapshot_id;
    delete from apxtm_artifacts where artifact_id=art
      and not exists(select 1 from apxtm_snapshots where artifact_id=art)
      and not exists(select 1 from apxtm_operations where expected_artifact_id=art or proposed_artifact_id=art);
    event(app,'RETENTION','SUCCESS','Explicitly deleted unreferenced snapshot '||p_snapshot_id);commit;
  exception when others then rollback;raise;
  end;
end apxtm_engine;
/
