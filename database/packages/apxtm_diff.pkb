create or replace package body apxtm_diff as
  function compare_sources(p_baseline clob,p_current clob) return json_array_t is
    type t_components is table of json_object_t index by varchar2(512);
    type t_names is table of boolean index by varchar2(128);
    b json_array_t:=apxtm_parse.parse(p_baseline);
    c json_array_t:=apxtm_parse.parse(p_current);
    bm t_components; cm t_components;
    result json_array_t:=json_array_t();
    bc json_object_t; cc json_object_t; ba json_object_t; ca json_object_t;
    keys json_key_list; names t_names;
    k varchar2(512); p varchar2(128); bv varchar2(4000); cv varchar2(4000);
    status varchar2(20); eligibility varchar2(1); reason varchar2(500);
    identity_conflict boolean;

    function is_layout(p_kind varchar2,p_name varchar2) return boolean is
    begin
      if p_name in ('p_id','p_name','p_plug_name','p_button_name','p_plug_id','p_button_plug_id',
        'p_parent_plug_id','p_theme_id','p_theme_class_id','p_internal_name','p_reference_id',
        'p_template_id','p_css_classes','p_theme_internal_name') then return false; end if;
      return p_kind in ('PAGE','REGION','ITEM','BUTTON','THEME');
    end;

    function option_set(p_value varchar2) return varchar2 is
      r varchar2(4000);
    begin
      select listagg(column_value,':') within group(order by column_value) into r
      from (select distinct column_value from table(apex_string.split(p_value,':')));
      return r;
    end;

    procedure emit(p_component json_object_t,p_property varchar2,p_baseline varchar2,
      p_current varchar2,p_status varchar2,p_eligible varchar2,p_reason varchar2) is
      o json_object_t:=json_object_t();
    begin
      o.put('key',p_component.get_string('key')); o.put('kind',p_component.get_string('kind'));
      o.put('page',p_component.get_number('page')); o.put('name',p_component.get_string('name'));
      o.put('property',p_property); o.put('baseline',p_baseline); o.put('current',p_current);
      o.put('classification',p_status); o.put('eligible',p_eligible); o.put('reason',p_reason); result.append(o);
    end;

    procedure template_mapping(p_property varchar2,p_old_id varchar2,p_new_id varchar2,
      p_status out varchar2,p_reason out varchar2) is
      old_template json_object_t; t json_object_t; old_attrs json_object_t; ta json_object_t;
      expected_kind varchar2(30); n number:=0; old_count number:=0;
    begin
      expected_kind:=case
        when p_property in ('p_step_template','p_default_page_template','p_default_dialog_template',
          'p_dialog_template','p_error_template','p_printer_friendly_template','p_login_template') then 'PAGE_TEMPLATE'
        when p_property in ('p_field_template','p_default_label_template') then 'ITEM_TEMPLATE'
        when p_property in ('p_button_template','p_default_button_template') then 'BUTTON_TEMPLATE'
        else 'REGION_TEMPLATE' end;
      for i in 0..b.get_size-1 loop
        t:=treat(b.get(i) as json_object_t);
        if t.get_string('kind')=expected_kind and t.get_string('id')=p_old_id then old_template:=t;old_count:=old_count+1;end if;
      end loop;
      if old_count!=1 then
        p_status:='NO_MATCH'; p_reason:='Baseline template definition is not embedded; inherited theme references require manual review.'; return;
      end if;
      old_attrs:=old_template.get_object('attrs');
      for i in 0..c.get_size-1 loop
        t:=treat(c.get(i) as json_object_t); ta:=t.get_object('attrs');
        if t.get_string('kind')=expected_kind and t.get_string('name')=old_template.get_string('name')
          and nvl(ta.get_string('p_theme_class_id'),'#MISSING#')=nvl(old_attrs.get_string('p_theme_class_id'),'#MISSING#')
        then n:=n+1; end if;
      end loop;
      if n>1 then p_status:='AMBIGUOUS';p_reason:='Multiple templates match the type, name and class; automatic mapping is prohibited.';
      elsif n=0 then p_status:='NO_MATCH';p_reason:='No unique template candidate matches type, name and class.';
      else p_status:='CHANGED';p_reason:='Unique type/name/class candidate. A name or class match does not prove visual equivalence; manual review is required.';
      end if;
    end;
  begin
    for i in 0..b.get_size-1 loop bc:=treat(b.get(i) as json_object_t);bm(bc.get_string('key')):=bc;end loop;
    for i in 0..c.get_size-1 loop cc:=treat(c.get(i) as json_object_t);cm(cc.get_string('key')):=cc;end loop;
    k:=bm.first;
    while k is not null loop
      bc:=bm(k);
      if bc.get_string('kind') in ('PAGE','REGION','ITEM','BUTTON','THEME') then
        ba:=bc.get_object('attrs');
        if not cm.exists(k) then
          emit(bc,'__component__',bc.get_string('name'),null,'DROPPED','N','Component is absent or has a different ID; no identity is guessed.');
          keys:=ba.get_keys;
          for j in 1..keys.count loop
            if is_layout(bc.get_string('kind'),keys(j)) then emit(bc,keys(j),ba.get_string(keys(j)),null,'DROPPED','N','Component is absent; property recovery is unavailable.');end if;
          end loop;
        else
          cc:=cm(k);ca:=cc.get_object('attrs');names.delete;
          keys:=ba.get_keys;for j in 1..keys.count loop names(keys(j)):=true;end loop;
          keys:=ca.get_keys;for j in 1..keys.count loop names(keys(j)):=true;end loop;
          identity_conflict:=bc.get_string('name')!=cc.get_string('name') or bc.get_string('parent')!=cc.get_string('parent');
          p:=names.first;
          while p is not null loop
            if is_layout(bc.get_string('kind'),p) then
              bv:=ba.get_string(p);cv:=ca.get_string(p);eligibility:='N';
              if identity_conflict then status:='CONFLICT';reason:='Name or parent context changed for this component ID; review identity manually.';
              elsif bv is null then status:='ADDED';reason:='Property was not explicit in the baseline; no default is guessed.';
              elsif cv is null then status:='DROPPED';reason:='Property is no longer explicit; insertion is unsupported.';
              elsif bv='#EXPR#' or cv='#EXPR#' then status:='UNSUPPORTED';reason:='Export expression is outside the recognized scalar subset.';
              elsif bv=cv or (instr(p,'options')>0 and option_set(bv)=option_set(cv)) then
                status:='UNCHANGED';reason:='Recognized property has the same value or option set.';
              elsif instr(p,'options')>0 then status:='UNSUPPORTED';reason:='Template options are template-dependent CSS tokens; cross-template recovery is detection-only.';
              elsif instr(p,'template')>0 then template_mapping(p,bv,cv,status,reason);
              else
                status:='CHANGED';reason:='Detected change; this property requires manual review.';
                if apxtm_parse.is_recoverable(bc.get_string('kind'),p,bv)
                  and apxtm_parse.is_recoverable(cc.get_string('kind'),p,cv) then
                  eligibility:='Y';reason:='Recognized explicit grid/row scalar. Preview and fresh-state validation are required.';
                end if;
              end if;
              emit(bc,p,bv,cv,status,eligibility,reason);
            end if;
            p:=names.next(p);
          end loop;
        end if;
      end if;
      k:=bm.next(k);
    end loop;
    k:=cm.first;
    while k is not null loop
      cc:=cm(k);
      if not bm.exists(k) and cc.get_string('kind') in ('PAGE','REGION','ITEM','BUTTON','THEME') then
        emit(cc,'__component__',null,cc.get_string('name'),'ADDED','N','New component; the baseline has no corresponding identity.');
        ca:=cc.get_object('attrs');keys:=ca.get_keys;
        for j in 1..keys.count loop if is_layout(cc.get_string('kind'),keys(j)) then
          emit(cc,keys(j),null,ca.get_string(keys(j)),'ADDED','N','New component; no baseline property.');end if;end loop;
      end if;
      k:=cm.next(k);
    end loop;
    return result;
  end;
end apxtm_diff;
/
