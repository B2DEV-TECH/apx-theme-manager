declare
  denied boolean:=false;
begin
  begin apxtm_engine.assert_access(999999999,'READ');
  exception when others then if sqlcode=-20020 then denied:=true; else raise; end if; end;
  if not denied then raise_application_error(-20999,'Default installation authorized an application'); end if;
end;
/
