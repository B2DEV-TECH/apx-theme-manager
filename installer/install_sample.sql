-- SPDX-License-Identifier: Apache-2.0
-- Required NUMBER binds: :apxtm_workspace_id, :apxtm_sample_app_id.
-- Declare NUMBER :apxtm_sample_offset as an OUT bind and save its exact value.
-- New synthetic sample only. Existing applications are never overwritten.
-- Start SQL*Plus in the repository root; includes are relative to that directory.
whenever oserror exit failure rollback
whenever sqlerror exit failure rollback
set define off verify off echo off serveroutput on sqlblanklines on

@installer/preflight.sql
declare
  l_workspace_id number := :apxtm_workspace_id;
  l_app_id number := :apxtm_sample_app_id;
  l_alias varchar2(255);
  l_count number;
begin
  if l_workspace_id is null or l_workspace_id<=0 or l_workspace_id<>trunc(l_workspace_id)
     or l_app_id is null or l_app_id<=0 or l_app_id<>trunc(l_app_id) then
    raise_application_error(-20060,'Set positive integer workspace and unused sample application ID binds');
  end if;
  select count(*) into l_count from apex_workspace_schemas
   where workspace_id=l_workspace_id and schema=sys_context('USERENV','SESSION_USER');
  if l_count<>1 then raise_application_error(-20060,'Workspace is not assigned to this parsing schema'); end if;
  apex_util.set_security_group_id(l_workspace_id);
  select count(*) into l_count from apex_applications where application_id=l_app_id;
  if l_count<>0 then raise_application_error(-20060,'Application ID is already in use; sample overwrite is refused'); end if;
  l_alias := 'APXTM-LAYOUT-LAB-'||to_char(l_app_id,'TM9');
  select count(*) into l_count from apex_applications
   where workspace_id=l_workspace_id and alias=l_alias;
  if l_count<>0 then raise_application_error(-20060,'Sample alias is already in use'); end if;
  apex_application_install.clear_all;
  apex_application_install.set_workspace_id(l_workspace_id);
  apex_application_install.set_schema(sys_context('USERENV','SESSION_USER'));
  apex_application_install.set_application_id(l_app_id);
  apex_application_install.set_application_name('APXTM Layout Lab');
  apex_application_install.set_application_alias(l_alias);
  apex_application_install.generate_offset;
  :apxtm_sample_offset := apex_application_install.get_offset;
  if :apxtm_sample_offset is null or :apxtm_sample_offset<=0
     or :apxtm_sample_offset<>trunc(:apxtm_sample_offset) then
    raise_application_error(-20060,'Public generated sample offset is invalid');
  end if;
  apex_application_install.set_auto_install_sup_obj(false);
end;
/
@samples/layout-lab/exports/baseline/f105.sql
whenever oserror exit failure rollback
whenever sqlerror exit failure rollback
set define off verify off echo off serveroutput on sqlblanklines on
commit;

declare
  l_workspace_id number := :apxtm_workspace_id;
  l_app_id number := :apxtm_sample_app_id;
  l_offset number := :apxtm_sample_offset;
  l_count number;
  l_files apex_t_export_files;
  l_info apex_application_install.t_file_info;
  procedure free_files is
  begin
    if l_files is not null then
      for i in 1..l_files.count loop
        if dbms_lob.istemporary(l_files(i).contents)=1 then dbms_lob.freetemporary(l_files(i).contents); end if;
        if dbms_lob.istemporary(l_files(i).contents_blob)=1 then dbms_lob.freetemporary(l_files(i).contents_blob); end if;
      end loop;
    end if;
  end;
begin
  apex_util.set_security_group_id(l_workspace_id);
  select count(*) into l_count from apex_applications
   where application_id=l_app_id and workspace_id=l_workspace_id
     and owner=sys_context('USERENV','SESSION_USER') and application_name='APXTM Layout Lab'
     and alias='APXTM-LAYOUT-LAB-'||to_char(l_app_id,'TM9');
  if l_count<>1 then raise_application_error(-20060,'Imported sample identity does not match the requested target'); end if;
  select count(*) into l_count from apex_application_page_items
   where application_id=l_app_id and
     ((page_id=1 and item_name='P1_PROJECT' and item_id=7405520579042701+l_offset and grid_column_span=6)
       or (page_id=2 and item_name='P2_SUMMARY' and item_id=7406228470042704+l_offset and grid_column_span=6));
  if l_count<>2 then raise_application_error(-20060,'Imported sample IDs or baseline layout do not match the saved offset'); end if;
  apex_application_install.clear_all;
  l_files := apex_export.get_application(p_application_id=>l_app_id,p_type=>'SQL',p_split=>false,
    p_with_date=>false,p_with_audit_info=>null,p_with_supporting_objects=>'N');
  if l_files.count<>1 then raise_application_error(-20060,'Independent sample export is incomplete'); end if;
  l_info := apex_application_install.get_info(l_files);
  if l_info.app_id is null or l_info.app_id<>l_app_id or l_info.workspace_id is null
     or l_info.workspace_id<>l_workspace_id or l_info.app_owner is null
     or upper(l_info.app_owner)<>upper(sys_context('USERENV','SESSION_USER')) then
    raise_application_error(-20060,'Independent sample export identity does not match');
  end if;
  free_files;
  apex_application_install.clear_all;
  dbms_output.put_line('Synthetic baseline installed and independently checked. Application: '||to_char(l_app_id,'TM9'));
  dbms_output.put_line('Save this exact sample offset for apply_changed.sql: '||to_char(l_offset,'TM9'));
  dbms_output.put_line('Reconnect before owner registration or other manager operations. Recovery remains a separate disabled-by-default policy.');
exception when others then
  free_files;
  apex_application_install.clear_all;
  raise;
end;
/
