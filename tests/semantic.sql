declare
 b clob:=q'~wwv_flow_imp_shared.create_theme(p_id=>wwv_flow_imp.id(42),p_theme_id=>42,p_default_page_template=>10);
wwv_flow_imp_page.create_page(p_id=>1,p_name=>'Test',p_step_template=>10);
wwv_flow_imp_page.create_page_item(p_id=>wwv_flow_imp.id(8),p_name=>'P1_X',p_colspan=>6,p_begin_on_new_line=>'Y');~';
 c clob:=q'~wwv_flow_imp_shared.create_theme(p_id=>wwv_flow_imp.id(42),p_theme_id=>42,p_default_page_template=>11);
wwv_flow_imp_page.create_page(p_id=>1,p_name=>'Test',p_step_template=>10);
wwv_flow_imp_page.create_page_item(p_id=>wwv_flow_imp.id(8),p_name=>'P1_X',p_colspan=>12,p_begin_on_new_line=>'N');~';
 a json_array_t; o json_object_t; eligible number:=0; defaults number:=0;
begin
 a:=apxtm_diff.compare_sources(b,c);
 for i in 0..a.get_size-1 loop
  o:=treat(a.get(i) as json_object_t);
  if o.get_string('eligible')='Y' then eligible:=eligible+1; end if;
  if o.get_string('property')='p_default_page_template' and o.get_string('classification')='NO_MATCH' then defaults:=defaults+1; end if;
 end loop;
 if eligible!=2 or defaults!=1 then raise_application_error(-20999,'Wrong scalar eligibility or omitted theme defaults'); end if;
end;
/

-- Actual export parameter names, including non-page template names.
declare
 b clob:=q'~wwv_flow_imp_shared.create_button_templates(p_id=>wwv_flow_imp.id(10),p_template_name=>'Action',p_theme_class_id=>1,p_theme_id=>42);
wwv_flow_imp_shared.create_plug_template(p_id=>wwv_flow_imp.id(30),p_page_plug_template_name=>'Panel',p_theme_class_id=>1,p_theme_id=>42);
wwv_flow_imp_page.create_page(p_id=>1,p_name=>'Test');
wwv_flow_imp_page.create_page_plug(p_id=>wwv_flow_imp.id(40),p_plug_name=>'Panel',p_region_template_options=>'a',p_plug_item_display_point=>'ABOVE');
wwv_flow_imp_page.create_page_button(p_id=>wwv_flow_imp.id(8),p_button_name=>'NEXT',p_button_template_id=>10);~';
 c clob:=q'~wwv_flow_imp_shared.create_button_templates(p_id=>wwv_flow_imp.id(20),p_template_name=>'Action',p_theme_class_id=>1,p_theme_id=>43);
wwv_flow_imp_shared.create_plug_template(p_id=>wwv_flow_imp.id(30),p_page_plug_template_name=>'Panel',p_theme_class_id=>1,p_theme_id=>42);
wwv_flow_imp_page.create_page(p_id=>1,p_name=>'Test');
wwv_flow_imp_page.create_page_plug(p_id=>wwv_flow_imp.id(40),p_plug_name=>'Panel',p_region_template_options=>'b',p_plug_item_display_point=>'BELOW');
wwv_flow_imp_page.create_page_button(p_id=>wwv_flow_imp.id(8),p_button_name=>'NEXT',p_button_template_id=>20);~';
 a json_array_t;o json_object_t;button_changes number:=0;option_changes number:=0;display_changes number:=0;
begin
 a:=apxtm_diff.compare_sources(b,c);
 for i in 0..a.get_size-1 loop
  o:=treat(a.get(i) as json_object_t);
  if o.get_string('property')='p_button_template_id' and o.get_string('classification')='CHANGED' and o.get_string('eligible')='N' then button_changes:=button_changes+1;end if;
  if o.get_string('property')='p_region_template_options' and o.get_string('classification')='UNSUPPORTED' and o.get_string('eligible')='N' then option_changes:=option_changes+1;end if;
  if o.get_string('property')='p_plug_item_display_point' and o.get_string('classification')='CHANGED' and o.get_string('eligible')='N' then display_changes:=display_changes+1;end if;
 end loop;
 if button_changes!=1 or option_changes!=1 or display_changes!=1 then raise_application_error(-20999,'Actual button-template/region-option/display-point spelling was missed');end if;
 a:=apxtm_parse.parse(b);o:=treat(a.get(1) as json_object_t);
 if o.get_string('name')!='Panel' then raise_application_error(-20999,'Region template export name was lost');end if;
end;
/

-- Actual 26.2 item exports identify their owning region with p_item_plug_id.
declare
 b clob:=q'~wwv_flow_imp_page.create_page(p_id=>1,p_name=>'Test');
wwv_flow_imp_page.create_page_item(p_id=>wwv_flow_imp.id(8),p_name=>'P1_X',p_item_plug_id=>wwv_flow_imp.id(20),p_colspan=>6);~';
 c clob:=q'~wwv_flow_imp_page.create_page(p_id=>1,p_name=>'Test');
wwv_flow_imp_page.create_page_item(p_id=>wwv_flow_imp.id(8),p_name=>'P1_X',p_item_plug_id=>wwv_flow_imp.id(21),p_colspan=>12);~';
 a json_array_t; o json_object_t;
begin
 a:=apxtm_diff.compare_sources(b,c);
 if a.get_size!=1 then raise_application_error(-20999,'Parent metadata emitted as layout property');end if;
 o:=treat(a.get(0) as json_object_t);
 if o.get_string('property')!='p_colspan' or o.get_string('classification')!='CONFLICT' or o.get_string('eligible')!='N' then
  raise_application_error(-20999,'Moved item with actual export parent parameter remained eligible');end if;
 a:=apxtm_parse.parse(b);o:=treat(a.get(1) as json_object_t);
 if o.get_string('parent')!='20' then raise_application_error(-20999,'Actual item parent parameter was not extracted');end if;
end;
/
declare
 b clob:=q'~wwv_flow_imp_shared.create_theme(p_id=>wwv_flow_imp.id(42),p_theme_id=>42,p_files_version=>123);
wwv_flow_imp_page.create_page(p_id=>1,p_name=>'Test',p_step_template=>10,p_page_template_options=>'#DEFAULT#');~';
 c clob:=q'~wwv_flow_imp_shared.create_theme(p_id=>wwv_flow_imp.id(42),p_theme_id=>42,p_files_version=>456789);
wwv_flow_imp_page.create_page(p_id=>1,p_name=>'Test',p_step_template=>10,p_page_template_options=>'#DEFAULT#');~';
 a json_array_t;o json_object_t;
begin
 a:=apxtm_diff.compare_sources(b,c);
 for i in 0..a.get_size-1 loop o:=treat(a.get(i) as json_object_t);
  if o.get_string('classification')!='UNCHANGED' then raise_application_error(-20999,'Theme cache counter caused a semantic difference');end if;
 end loop;
end;
/
declare
 -- Exact construct used by the actual 26.2 SQL export; both theme definitions remain.
 b clob:=q'~wwv_imp_workspace.create_flow(p_id=>wwv_flow.g_flow_id,p_name=>'APXTM Layout Lab',p_theme_id=>42);
wwv_flow_imp_shared.create_theme(p_id=>wwv_flow_imp.id(42),p_theme_id=>42);
wwv_flow_imp_shared.create_theme(p_id=>wwv_flow_imp.id(43),p_theme_id=>43);
wwv_flow_imp_page.create_page(p_id=>1,p_name=>'Test');~';
 c clob:=q'~wwv_imp_workspace.create_flow(p_id=>wwv_flow.g_flow_id,p_name=>'APXTM Layout Lab',p_theme_id=>43);
wwv_flow_imp_shared.create_theme(p_id=>wwv_flow_imp.id(42),p_theme_id=>42);
wwv_flow_imp_shared.create_theme(p_id=>wwv_flow_imp.id(43),p_theme_id=>43);
wwv_flow_imp_page.create_page(p_id=>1,p_name=>'Test');~';
 a json_array_t;o json_object_t;n number:=0;
begin
 a:=apxtm_diff.compare_sources(b,c);
 for i in 0..a.get_size-1 loop o:=treat(a.get(i) as json_object_t);
  if o.get_string('kind')='APPLICATION' and o.get_string('property')='p_theme_id' and o.get_string('classification')='CHANGED' and o.get_string('eligible')='N' then n:=n+1;end if;
 end loop;
 if n!=1 then raise_application_error(-20999,'Real-format active-theme switch was invisible');end if;
end;
/
declare
 b clob:=q'~wwv_flow_imp_shared.create_template(p_id=>wwv_flow_imp.id(10),p_name=>'Standard',p_theme_class_id=>1,p_theme_id=>42,p_header_template=>'<header>before</header>');
wwv_flow_imp_page.create_page(p_id=>1,p_name=>'Test',p_step_template=>wwv_flow_imp.id(10));~';
 c clob:=q'~wwv_flow_imp_shared.create_template(p_id=>wwv_flow_imp.id(10),p_name=>'Standard',p_theme_class_id=>1,p_theme_id=>42,p_header_template=>'<header>after</header>');
wwv_flow_imp_page.create_page(p_id=>1,p_name=>'Test',p_step_template=>wwv_flow_imp.id(10));~';
 a json_array_t;o json_object_t;n number:=0;
begin
 a:=apxtm_diff.compare_sources(b,c);
 for i in 0..a.get_size-1 loop o:=treat(a.get(i) as json_object_t);
  if o.get_string('property')='p_step_template' and o.get_string('classification')='CHANGED' and o.get_string('eligible')='N' then n:=n+1;end if;
 end loop;
 if n!=1 then raise_application_error(-20999,'Same template ID concealed changed template definition');end if;
end;
/
declare
 b clob:=q'~wwv_flow_imp_shared.create_theme(p_id=>wwv_flow_imp.id(42),p_theme_id=>42);
wwv_flow_imp_shared.create_theme(p_id=>wwv_flow_imp.id(43),p_theme_id=>43);
wwv_flow_imp.create_user_interface(p_id=>wwv_flow_imp.id(500),p_theme_id=>42);
wwv_flow_imp_page.create_page(p_id=>1,p_name=>'Test');~';
 c clob:=q'~wwv_flow_imp_shared.create_theme(p_id=>wwv_flow_imp.id(42),p_theme_id=>42);
wwv_flow_imp_shared.create_theme(p_id=>wwv_flow_imp.id(43),p_theme_id=>43);
wwv_flow_imp.create_user_interface(p_id=>wwv_flow_imp.id(500),p_theme_id=>43);
wwv_flow_imp_page.create_page(p_id=>1,p_name=>'Test');~';
 a json_array_t;o json_object_t;n number:=0;
begin
 a:=apxtm_diff.compare_sources(b,c);
 for i in 0..a.get_size-1 loop o:=treat(a.get(i) as json_object_t);
  if o.get_string('kind')='USER_INTERFACE' and o.get_string('property')='p_theme_id' and o.get_string('classification')='CHANGED' and o.get_string('eligible')='N' then n:=n+1;end if;
 end loop;
 if n!=1 then raise_application_error(-20999,'Switch between existing themes was invisible');end if;
end;
/
declare
 b clob:=q'~wwv_flow_imp_shared.create_template(p_id=>wwv_flow_imp.id(10),p_name=>'Standard',p_theme_class_id=>1,p_theme_id=>42);
wwv_flow_imp_page.create_page(p_id=>1,p_name=>'Test',p_step_template=>wwv_flow_imp.id(10));~';
 c clob:=q'~wwv_flow_imp_shared.create_template(p_id=>wwv_flow_imp.id(20),p_name=>'Standard',p_theme_class_id=>1,p_theme_id=>43);
wwv_flow_imp_shared.create_template(p_id=>wwv_flow_imp.id(21),p_name=>'Standard',p_theme_class_id=>1,p_theme_id=>43);
wwv_flow_imp_page.create_page(p_id=>1,p_name=>'Test',p_step_template=>wwv_flow_imp.id(20));~';
 a json_array_t; o json_object_t; ambiguous number:=0;
begin
 a:=apxtm_diff.compare_sources(b,c);
 for i in 0..a.get_size-1 loop
  o:=treat(a.get(i) as json_object_t);
  if o.get_string('property')='p_step_template' and o.get_string('classification')='AMBIGUOUS' and o.get_string('eligible')='N' then ambiguous:=ambiguous+1; end if;
 end loop;
 if ambiguous!=1 then raise_application_error(-20999,'Duplicated template names did not block mapping'); end if;
end;
/
declare
 b clob:=q'~wwv_flow_imp_page.create_page(p_id=>1,p_name=>'Test',p_page_template_options=>'a:b');
wwv_flow_imp_page.create_page_item(p_id=>wwv_flow_imp.id(8),p_name=>'P1_X',p_colspan=>6);~';
 c clob:=q'~wwv_flow_imp_page.create_page(p_id=>1,p_name=>'Test',p_page_template_options=>'b:a');
wwv_flow_imp_page.create_page_item(p_id=>wwv_flow_imp.id(8),p_name=>'P1_RECREATED',p_colspan=>12);
wwv_flow_imp_page.create_page_button(p_id=>wwv_flow_imp.id(9),p_button_name=>'NEW',p_grid_column_span=>3);~';
 a json_array_t; o json_object_t; conflicts number:=0; added number:=0; same number:=0;
begin
 a:=apxtm_diff.compare_sources(b,c);
 for i in 0..a.get_size-1 loop
  o:=treat(a.get(i) as json_object_t);
  if o.get_string('classification')='CONFLICT' and o.get_string('eligible')='N' then conflicts:=conflicts+1; end if;
  if o.get_string('classification')='ADDED' then added:=added+1; end if;
  if o.get_string('property')='p_page_template_options' and o.get_string('classification')='UNCHANGED' then same:=same+1; end if;
 end loop;
 if conflicts!=1 or added<1 or same!=1 then raise_application_error(-20999,'Wrong structural identity or option-set comparison'); end if;
end;
/
