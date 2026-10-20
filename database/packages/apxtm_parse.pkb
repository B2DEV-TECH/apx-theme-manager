create or replace package body apxtm_parse as
  procedure reject(p_message varchar2) is
  begin raise_application_error(-20001,p_message); end;

  function is_recoverable(p_kind varchar2,p_property varchar2,p_value varchar2) return boolean is
    l_max number := 12;
    l_min number := 1;
  begin
    if p_kind not in ('REGION','ITEM','BUTTON') or p_kind is null
       or p_property is null or p_value is null then return false; end if;
    if p_kind='REGION' and p_property='p_plug_new_grid_row' then return p_value in ('TRUE','FALSE');end if;
    if (p_kind='ITEM' and p_property in ('p_begin_on_new_line','p_begin_on_new_field'))
      or (p_kind='BUTTON' and p_property in ('p_grid_new_row','p_grid_new_column'))
    then return p_value in ('Y','N'); end if;
    if (p_kind='ITEM' and p_property in ('p_colspan','p_rowspan','p_grid_column','p_grid_label_column_span'))
      or (p_kind='REGION' and p_property in ('p_plug_grid_column_span','p_grid_column','p_grid_column_span','p_grid_row_span'))
      or (p_kind='BUTTON' and p_property in ('p_grid_column','p_grid_column_span')) then
      if not regexp_like(p_value,'^[0-9]{1,3}$') then return false; end if;
      if p_property='p_grid_label_column_span' then l_min:=0; end if;
      if p_property in ('p_rowspan','p_grid_row_span') then l_max:=100; end if;
      return to_number(p_value) between l_min and l_max;
    end if;
    return false;
  end;

  function parse(p_source clob) return json_array_t is
    type t_token is record(txt varchar2(256), first_pos pls_integer,last_pos pls_integer);
    type t_seen is table of boolean index by varchar2(512);
    l_seen t_seen;
    l_result json_array_t := json_array_t();
    l_size pls_integer := dbms_lob.getlength(p_source);
    l_pos pls_integer := 1;
    l_cache varchar2(32767);
    l_cache_start pls_integer := 0;
    l_page number := 0;
    l_token t_token;
    l_prefix varchar2(256);
    l_call varchar2(256);
    l_kind varchar2(20);
    l_component json_object_t;
    l_attrs json_object_t;
    l_spans json_object_t;
    l_span json_object_t;
    l_key varchar2(512);
    l_param varchar2(256);
    l_first pls_integer;
    l_last pls_integer;
    l_depth pls_integer;
    l_value varchar2(32767);
    l_raw varchar2(32767);
    l_id varchar2(256);
    l_expression_tokens pls_integer;

    function ch(p_at pls_integer) return varchar2 is
    begin
      if p_at<1 or p_at>l_size then return null; end if;
      if p_at<l_cache_start or p_at>=l_cache_start+length(l_cache) or l_cache is null then
        l_cache_start:=p_at;
        -- Amount is in characters; a small cache is safe with multibyte UTF-8.
        l_cache:=dbms_lob.substr(p_source,8000,p_at);
      end if;
      return substr(l_cache,p_at-l_cache_start+1,1);
    end;

    function token return t_token is
      r t_token;
      c varchar2(1);
      d varchar2(1);
      e varchar2(1);
      done boolean;
    begin
      loop
        c:=ch(l_pos);
        exit when c is null;
        if c in (' ',chr(9),chr(10),chr(13)) then l_pos:=l_pos+1;
        elsif c='-' and ch(l_pos+1)='-' then
          l_pos:=l_pos+2;
          while ch(l_pos) is not null and ch(l_pos)!=chr(10) loop l_pos:=l_pos+1; end loop;
        elsif c='/' and ch(l_pos+1)='*' then
          l_pos:=l_pos+2;
          while ch(l_pos) is not null and not(ch(l_pos)='*' and ch(l_pos+1)='/') loop l_pos:=l_pos+1; end loop;
          if ch(l_pos) is null then reject('Unterminated block comment'); end if;
          l_pos:=l_pos+2;
        else exit;
        end if;
      end loop;
      r.first_pos:=l_pos;
      if c is null then r.txt:=null; r.last_pos:=l_pos; return r; end if;
      if lower(c)='q' and ch(l_pos+1)='''' then
        d:=ch(l_pos+2);
        if d is null or d in (' ',chr(9),chr(10),chr(13),'''') then reject('Invalid alternative quote'); end if;
        e:=case d when '[' then ']' when '(' then ')' when '{' then '}' when '<' then '>' else d end;
        l_pos:=l_pos+3;
        while ch(l_pos) is not null and not(ch(l_pos)=e and ch(l_pos+1)='''') loop l_pos:=l_pos+1; end loop;
        if ch(l_pos) is null then reject('Unterminated alternative quote'); end if;
        l_pos:=l_pos+2; r.txt:='#STRING#';
      elsif c in ('''','"') then
        d:=c; l_pos:=l_pos+1; done:=false;
        while ch(l_pos) is not null loop
          if ch(l_pos)=d then
            if ch(l_pos+1)=d then l_pos:=l_pos+2;
            else l_pos:=l_pos+1; done:=true; exit; end if;
          else l_pos:=l_pos+1; end if;
        end loop;
        if not done then reject('Unterminated quoted literal'); end if;
        r.txt:='#STRING#';
      elsif regexp_like(c,'[A-Za-z0-9_$#]') then
        l_pos:=l_pos+1;
        while ch(l_pos) is not null and regexp_like(ch(l_pos),'[A-Za-z0-9_$#]') loop l_pos:=l_pos+1; end loop;
        if l_pos-r.first_pos>256 then r.txt:='#LONG#';
        else r.txt:=lower(dbms_lob.substr(p_source,l_pos-r.first_pos,r.first_pos)); end if;
      else
        l_pos:=l_pos+1; r.txt:=c;
        if c='=' and ch(l_pos)='>' then r.txt:='=>'; l_pos:=l_pos+1; end if;
      end if;
      r.last_pos:=l_pos-1;
      return r;
    end;

    function wanted(p_name varchar2) return boolean is
    begin
      return p_name in ('p_id','p_name','p_plug_name','p_button_name','p_plug_id','p_button_plug_id',
        'p_parent_plug_id','p_theme_id','p_theme_class_id','p_internal_name','p_reference_id',
        'p_template_id','p_css_classes','p_theme_internal_name','p_template','p_plug_template',
        'p_step_template','p_page_template_options','p_template_options','p_field_template',
        'p_item_template_options','p_button_template','p_button_template_options','p_button_position',
        'p_plug_display_point','p_plug_display_column','p_begin_on_new_line','p_begin_on_new_field',
        'p_colspan','p_rowspan','p_grid_column','p_grid_column_span','p_grid_row_span',
        'p_grid_label_column_span','p_plug_new_grid_row','p_plug_grid_column_span',
        'p_grid_new_row','p_grid_new_column','p_default_page_template','p_default_dialog_template',
        'p_error_template','p_printer_friendly_template','p_login_template',
        'p_default_region_template','p_default_chart_template','p_default_form_template',
        'p_default_reportr_template','p_default_tabform_template','p_default_wizard_template',
        'p_default_menur_template','p_default_listr_template','p_default_irr_template',
        'p_default_report_template','p_default_label_template','p_default_menu_template',
        'p_default_calendar_template','p_default_list_template','p_default_nav_list_template',
        'p_default_top_nav_list_temp','p_default_side_nav_list_temp','p_default_button_template',
        'p_dialog_template','p_nav_bar_list_template');
    end;

    function scalar(p_text varchar2) return varchar2 is
      s varchar2(32767):=trim(p_text);
    begin
      if s is null then reject('Empty export expression'); end if;
      if lower(s)='null' then return '#NULL#'; end if;
      if lower(s) in ('true','false') then return upper(s);end if;
      if s='0' then return '0'; end if;
      if regexp_like(s,'^[0-9]+$') then return nvl(ltrim(s,'0'),'0'); end if;
      if regexp_like(s,'^wwv_flow_imp[.]id\([[:space:]]*[0-9]+[[:space:]]*\)$','i') then
        return regexp_substr(s,'[0-9]+');
      end if;
      if l_expression_tokens=1 and substr(s,1,1)='''' and substr(s,-1)='''' then
        return replace(substr(s,2,length(s)-2),'''''','''');
      end if;
      if l_expression_tokens=1 and lower(substr(s,1,2))='q''' and substr(s,-1)='''' then return substr(s,4,length(s)-5); end if;
      return '#EXPR#';
    end;

    function component_kind(p_call varchar2) return varchar2 is
    begin
      return case p_call
        when 'create_page' then 'PAGE' when 'create_page_plug' then 'REGION'
        when 'create_page_item' then 'ITEM' when 'create_page_button' then 'BUTTON'
        when 'create_theme' then 'THEME' when 'create_template' then 'PAGE_TEMPLATE'
        when 'create_plug_template' then 'REGION_TEMPLATE'
        when 'create_field_template' then 'ITEM_TEMPLATE'
        when 'create_button_templates' then 'BUTTON_TEMPLATE'
        when 'create_template_option' then 'TEMPLATE_OPTION' else null end;
    end;
  begin
    if p_source is null or l_size=0 then reject('Empty application export'); end if;
    loop
      l_token:=token; exit when l_token.txt is null;
      if l_token.txt in ('wwv_flow_imp_page','wwv_flow_imp_shared','wwv_flow_imp') then
        l_prefix:=l_token.txt; l_token:=token;
        if l_token.txt='.' then
          l_token:=token; l_call:=l_token.txt; l_kind:=component_kind(l_call);
          if l_kind is not null then
            l_token:=token;
            if l_token.txt!='(' then reject('Expected component parameter list'); end if;
            l_component:=json_object_t(); l_attrs:=json_object_t(); l_spans:=json_object_t();
            loop
              l_token:=token;
              if l_token.txt=')' then exit; end if;
              l_param:=l_token.txt;
              if not regexp_like(l_param,'^p_[a-z0-9_]+$') or l_param is null then reject('Expected named parameter'); end if;
              l_token:=token; if l_token.txt!='=>' then reject('Expected named parameter operator'); end if;
              l_token:=token; l_first:=l_token.first_pos; l_last:=0; l_depth:=0; l_expression_tokens:=0;
              loop
                if l_token.txt is null then reject('Unterminated component call'); end if;
                exit when l_depth=0 and l_token.txt in (',',')');
                if l_token.txt='(' then l_depth:=l_depth+1;
                elsif l_token.txt=')' then l_depth:=l_depth-1; end if;
                if l_depth<0 then reject('Invalid parentheses'); end if;
                l_expression_tokens:=l_expression_tokens+1; l_last:=l_token.last_pos; l_token:=token;
              end loop;
              if l_last<l_first then reject('Empty parameter value'); end if;
              if wanted(l_param) then
                if l_attrs.has(l_param) then reject('Duplicate named parameter'); end if;
                if l_last-l_first+1>4000 then l_value:='#EXPR#'; l_raw:=null;
                else l_raw:=dbms_lob.substr(p_source,l_last-l_first+1,l_first); l_value:=scalar(l_raw); end if;
                -- Oracle empty strings are represented distinctly from absent attributes.
                l_attrs.put(l_param,nvl(l_value,'#EMPTY#'));
                l_span:=json_object_t(); l_span.put('start',l_first); l_span.put('end',l_last);
                l_span.put('raw',l_raw); l_spans.put(l_param,l_span);
              end if;
              exit when l_token.txt=')';
            end loop;
            if not l_attrs.has('p_id') then reject('Component ID missing'); end if;
            l_id:=l_attrs.get_string('p_id');
            if not regexp_like(l_id,'^[0-9]+$') then reject('Unsupported component ID expression'); end if;
            if l_kind='PAGE' then l_page:=to_number(l_id); end if;
            l_component.put('kind',l_kind); l_component.put('call',l_call);
            l_component.put('id',l_id);
            if l_kind in ('PAGE','REGION','ITEM','BUTTON') then l_component.put('page',l_page);
            else l_component.put('page',0); end if;
            l_component.put('name',coalesce(l_attrs.get_string('p_name'),l_attrs.get_string('p_plug_name'),l_attrs.get_string('p_button_name'),l_id));
            l_component.put('parent',coalesce(l_attrs.get_string('p_plug_id'),l_attrs.get_string('p_button_plug_id'),l_attrs.get_string('p_parent_plug_id'),'#NULL#'));
            l_key:=l_kind||':'||l_component.get_number('page')||':'||l_id;
            if l_seen.exists(l_key) then reject('Duplicate component identity'); end if;
            l_seen(l_key):=true;
            l_component.put('key',l_key); l_component.put('attrs',l_attrs); l_component.put('spans',l_spans);
            l_result.append(l_component);
          end if;
        end if;
      end if;
    end loop;
    if l_result.get_size=0 then reject('No recognized components in export'); end if;
    return l_result;
  end;

  function patch(p_source clob,p_changes json_array_t) return clob is
    type t_edit is record(last_pos pls_integer,value varchar2(4000));
    type t_edits is table of t_edit index by pls_integer;
    l_edits t_edits;
    l_components json_array_t:=parse(p_source);
    l_component json_object_t;
    l_change json_object_t;
    l_attrs json_object_t;
    l_spans json_object_t;
    l_span json_object_t;
    l_property varchar2(128);
    l_value varchar2(4000);
    l_found boolean;
    l_at pls_integer;
    l_from pls_integer:=1;
    l_dest pls_integer:=1;
    l_amount pls_integer;
    l_result clob;
  begin
    if p_changes is null or p_changes.get_size=0 then reject('Select at least one eligible change'); end if;
    if p_changes.get_size>10000 then reject('Selection exceeds supported batch size'); end if;
    for i in 0..p_changes.get_size-1 loop
      l_change:=treat(p_changes.get(i) as json_object_t);
      l_property:=l_change.get_string('property'); l_value:=l_change.get_string('value'); l_found:=false;
      for j in 0..l_components.get_size-1 loop
        l_component:=treat(l_components.get(j) as json_object_t);
        if l_component.get_string('key')=l_change.get_string('key') then
          l_found:=true; l_attrs:=l_component.get_object('attrs');
          if not l_attrs.has(l_property) or not is_recoverable(l_component.get_string('kind'),l_property,l_value) then
            reject('Property is not eligible for automatic recovery');
          end if;
          if l_change.get_string('expected') is null or l_attrs.get_string(l_property)!=l_change.get_string('expected') then reject('Patch precondition conflict'); end if;
          l_spans:=l_component.get_object('spans'); l_span:=l_spans.get_object(l_property); l_at:=l_span.get_number('start');
          if l_edits.exists(l_at) then reject('Duplicate patch selection'); end if;
          l_edits(l_at).last_pos:=l_span.get_number('end');
          if l_value in ('Y','N') then l_edits(l_at).value:=''''||l_value||'''';
          elsif l_value in ('TRUE','FALSE') then l_edits(l_at).value:=lower(l_value);
          else l_edits(l_at).value:=l_value; end if;
          exit;
        end if;
      end loop;
      if not l_found then reject('Patch component is missing'); end if;
    end loop;
    dbms_lob.createtemporary(l_result,true);
    l_at:=l_edits.first;
    while l_at is not null loop
      l_amount:=l_at-l_from;
      if l_amount<0 then reject('Overlapping source positions'); end if;
      if l_amount>0 then dbms_lob.copy(l_result,p_source,l_amount,l_dest,l_from); l_dest:=l_dest+l_amount; end if;
      dbms_lob.writeappend(l_result,length(l_edits(l_at).value),l_edits(l_at).value);
      l_dest:=l_dest+length(l_edits(l_at).value); l_from:=l_edits(l_at).last_pos+1;
      l_at:=l_edits.next(l_at);
    end loop;
    l_amount:=dbms_lob.getlength(p_source)-l_from+1;
    if l_amount>0 then dbms_lob.copy(l_result,p_source,l_amount,l_dest,l_from); end if;
    l_components:=parse(l_result);
    return l_result;
  exception when others then
    if dbms_lob.istemporary(l_result)=1 then dbms_lob.freetemporary(l_result); end if;
    raise;
  end;
end apxtm_parse;
/
