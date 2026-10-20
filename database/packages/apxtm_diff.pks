create or replace package apxtm_diff authid definer as
  -- Pure analysis of export text. This package does not authorize or execute SQL.
  function compare_sources(p_baseline clob,p_current clob) return json_array_t;
end apxtm_diff;
/
