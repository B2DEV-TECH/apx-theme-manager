declare
  l_source clob := q'~prompt --application/pages/page_00001
begin
wwv_flow_imp_page.create_page(p_id=>1,p_name=>'Synthetic laboratório');
wwv_flow_imp_page.create_page_item(
 p_id=>wwv_flow_imp.id(200),p_name=>'P1_NAME',p_item_sequence=>10,
 p_prompt=>q'[A comma, a quote '' and a )]',p_begin_on_new_line=>'Y',p_colspan=>6);
end;
~';
  l_components json_array_t;
  l_component json_object_t;
  l_attrs json_object_t;
begin
  l_components := apxtm_parse.parse(l_source);
  if l_components.get_size != 2 then raise_application_error(-20999,'Expected exactly page and item'); end if;
  l_component := treat(l_components.get(1) as json_object_t);
  l_attrs := l_component.get_object('attrs');
  if l_component.get_string('kind')!='ITEM' or l_component.get_string('id')!='200'
    or l_component.get_number('page')!=1 or l_attrs.get_string('p_colspan')!='6'
    or l_attrs.get_string('p_begin_on_new_line')!='Y'
  then raise_application_error(-20999,'Incorrect component identity or semantic values'); end if;
end;
/
declare
 a json_array_t; c json_object_t;v json_object_t;s clob;patched clob;
begin
 s:=q'~wwv_flow_imp_page.create_page(p_id=>1,p_name=>'Test');
wwv_flow_imp_page.create_page_plug(p_id=>wwv_flow_imp.id(10),p_plug_name=>'Region',p_plug_new_grid_row=>false);~';
 a:=apxtm_parse.parse(s);c:=treat(a.get(1) as json_object_t);v:=c.get_object('attrs');
 if v.get_string('p_plug_new_grid_row')!='FALSE' then raise_application_error(-20999,'PL/SQL boolean not recognized');end if;
 patched:=apxtm_parse.patch(s,json_array_t('[{"key":"REGION:1:10","property":"p_plug_new_grid_row","expected":"FALSE","value":"TRUE"}]'));
 if dbms_lob.instr(patched,'p_plug_new_grid_row=>true')=0 then raise_application_error(-20999,'Boolean patch was not valid PL/SQL');end if;
 dbms_lob.freetemporary(patched);
end;
/
declare
  a json_array_t;
  c json_object_t;
begin
  a:=apxtm_parse.parse('begin wwv_flow_imp_page.create_page(p_id=>0,p_name=>''Global''); end;');
  c:=treat(a.get(0) as json_object_t);
  if c.get_number('page')!=0 then raise_application_error(-20999,'Global page zero lost'); end if;
end;
/
declare
  a json_array_t;
  c json_object_t;
  v json_object_t;
begin
  a:=apxtm_parse.parse(q'~begin
-- wwv_flow_imp_page.create_page(p_id=>999,p_name=>'Fake');
/* wwv_flow_imp_page.create_page_item(p_id=>10,p_name=>'FAKE'); */
wwv_flow_imp_page.create_page(p_id=>1,p_name=>'O''Brien');
wwv_flow_imp_page.create_page_item(p_id=>wwv_flow_imp.id(8),p_name=>'P1_X',
 p_begin_on_new_line=>'Y'||'N',p_colspan=>6);
end;~');
  if a.get_size!=2 then raise_application_error(-20999,'Comment interpreted as component'); end if;
  c:=treat(a.get(1) as json_object_t); v:=c.get_object('attrs');
  if v.get_string('p_begin_on_new_line')!='#EXPR#' then raise_application_error(-20999,'Expression accepted as scalar'); end if;
end;
/
declare
  s clob:=q'~begin
wwv_flow_imp_page.create_page(p_id=>1,p_name=>'Test');
wwv_flow_imp_page.create_page_item(p_id=>wwv_flow_imp.id(8),p_name=>'P1_X',p_colspan=>6);
end;~';
  want clob:=q'~begin
wwv_flow_imp_page.create_page(p_id=>1,p_name=>'Test');
wwv_flow_imp_page.create_page_item(p_id=>wwv_flow_imp.id(8),p_name=>'P1_X',p_colspan=>12);
end;~';
  actual clob;
begin
  actual:=apxtm_parse.patch(s,json_array_t('[{"key":"ITEM:1:8","property":"p_colspan","expected":"6","value":"12"}]'));
  if dbms_lob.compare(actual,want)!=0 then raise_application_error(-20999,'Patch changed unrelated source'); end if;
  dbms_lob.freetemporary(actual);
end;
/
declare
  a json_array_t;
  rejected boolean:=false;
begin
  begin
    a:=apxtm_parse.parse(q'~wwv_flow_imp_page.create_page(p_id=>1,p_name=>'A');
wwv_flow_imp_page.create_page(p_id=>1,p_name=>'B');~');
  exception when others then
    if sqlcode=-20001 then rejected:=true; else raise; end if;
  end;
  if not rejected then raise_application_error(-20999,'Duplicate identity accepted'); end if;
end;
/
declare
  a json_array_t;
  rejected boolean:=false;
begin
  begin a:=apxtm_parse.parse('begin wwv_flow_imp_page.create_page(p_id=>1,p_name=>q''[broken);');
  exception when others then if sqlcode=-20001 then rejected:=true; else raise; end if; end;
  if not rejected then raise_application_error(-20999,'Unclosed literal accepted'); end if;
end;
/
declare
  s clob:=q'~wwv_flow_imp_page.create_page(p_id=>1,p_name=>'Test');
wwv_flow_imp_page.create_page_item(p_id=>wwv_flow_imp.id(8),p_name=>'P1_X',p_colspan=>6);~';
  result clob;
  rejected boolean;
begin
  for i in 1..4 loop
    rejected:=false;
    begin
      result:=apxtm_parse.patch(s,json_array_t(case i
        when 1 then '[{"key":"ITEM:1:8","property":"p_name","expected":"P1_X","value":"P1_ATTACK"}]'
        when 2 then '[{"key":"ITEM:1:8","property":"p_colspan","expected":"6","value":"12);execute immediate ''drop table x'';"}]'
        when 3 then '[{"key":"ITEM:1:8","property":"p_colspan","expected":"9","value":"12"}]'
        when 4 then '[{"key":"ITEM:1:9","property":"p_colspan","expected":"6","value":"12"}]' end));
    exception when others then if sqlcode=-20001 then rejected:=true; else raise; end if; end;
    if not rejected then raise_application_error(-20999,'Unsafe or stale patch accepted case '||i); end if;
  end loop;
end;
/
declare
  s clob;
  a json_array_t;
  c json_object_t;
  block varchar2(4000):=rpad('x',3990,'x');
begin
  dbms_lob.createtemporary(s,true);
  dbms_lob.writeappend(s,2,'/*');
  for i in 1..30 loop dbms_lob.writeappend(s,length(block),block); end loop;
  block:=q'~*/
wwv_flow_imp_page.create_page(p_id=>1,p_name=>'Café laboratório');~';
  dbms_lob.writeappend(s,length(block),block);
  a:=apxtm_parse.parse(s); c:=treat(a.get(0) as json_object_t);
  if a.get_size!=1 or c.get_string('name')!='Café laboratório' then raise_application_error(-20999,'Large Unicode CLOB truncated'); end if;
  dbms_lob.freetemporary(s);
end;
/
