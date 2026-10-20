create or replace package apxtm_parse authid definer as
  -- Parses generated SQL exports as data. Never executes export expressions.
  function parse(p_source clob) return json_array_t;
  -- Conservative role/static-ID + literal assignment-expression fingerprint.
  function acl_fingerprint(p_source clob) return varchar2;
  function is_recoverable(p_kind varchar2,p_property varchar2,p_value varchar2) return boolean;
  -- Changes: [{key,property,expected,value}]. Only existing allowlisted scalars.
  function patch(p_source clob,p_changes json_array_t) return clob;
end apxtm_parse;
/
