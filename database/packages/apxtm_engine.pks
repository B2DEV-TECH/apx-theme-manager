create or replace package apxtm_engine authid definer as
  function actor return varchar2;
  function has_permission(p_permission varchar2 default 'READ') return boolean;
  function allowed(p_application_id number,p_permission varchar2 default 'READ') return number;
  -- History reads use the registered identity even if an import damaged the live app.
  function can_read_history(p_application_id number) return number;
  procedure assert_access(p_application_id number,p_permission varchar2 default 'READ');
  -- Registry is maintained by the database owner, never by runtime page items.
  procedure register_application(p_application_id number);
  function take_snapshot(p_application_id number,p_name varchar2 default null,
    p_kind varchar2 default 'BASELINE') return number;
  function validate_snapshot(p_snapshot_id number) return boolean;
  function snapshot_zip(p_snapshot_id number) return blob;
  function compare(p_snapshot_id number) return number;
  -- NULL IDs selects all eligible differences. Otherwise a colon-delimited list.
  procedure preview(p_comparison_id number,p_difference_ids varchar2 default null,
    p_operation_id out number,p_token out varchar2);
  procedure preview_restore(p_snapshot_id number,p_operation_id out number,p_token out varchar2);
  procedure apply(p_operation_id number,p_token varchar2,p_confirmation varchar2);
  function operation_zip(p_operation_id number) return blob;
  procedure retire_snapshot(p_snapshot_id number,p_confirmation varchar2);
end apxtm_engine;
/
