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
      or (p_kind='REGION' and p_property in ('p_plug_grid_column_span','p_plug_display_column','p_grid_column','p_grid_column_span','p_grid_row_span'))
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
    l_call_first pls_integer;
    l_definition clob;

    function at_command_start(p_at pls_integer) return boolean is
      i pls_integer:=p_at-1;
      c varchar2(1);
    begin
      while i>0 loop
        c:=dbms_lob.substr(p_source,1,i);
        if c in (chr(10),chr(13)) then return true;end if;
        if c not in (' ',chr(9)) then return false;end if;
        i:=i-1;
      end loop;
      return true;
    end;

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
        elsif lower(dbms_lob.substr(p_source,7,l_pos))='prompt ' and at_command_start(l_pos) then
          while ch(l_pos) is not null and ch(l_pos)!=chr(10) loop l_pos:=l_pos+1;end loop;
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
      return p_name in ('p_id','p_name','p_static_id','p_users','p_files_version','p_plug_display_sequence','p_item_sequence','p_button_sequence','p_plug_name','p_button_name','p_plug_id','p_item_plug_id','p_button_plug_id',
        'p_parent_plug_id','p_theme_id','p_theme_name','p_theme_version','p_theme_class_id','p_internal_name','p_reference_id',
        'p_template_id','p_template_name','p_page_plug_template_name','p_css_classes','p_theme_internal_name','p_template','p_plug_template',
        'p_step_template','p_page_template_options','p_template_options','p_field_template',
        'p_item_template_options','p_region_template_options','p_button_template','p_button_template_id','p_button_template_options','p_button_position',
        'p_plug_display_point','p_plug_item_display_point','p_plug_display_column','p_begin_on_new_line','p_begin_on_new_field',
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
        'p_default_dialogbtnr_template','p_default_dialogr_template','p_default_navbar_list_template',
        'p_default_option_label','p_default_required_label','p_current_theme_style_id',
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
      -- Recognize one tested generated-artifact construct as literal metadata.
      -- This internal export helper is never invoked by application code.
      if regexp_like(regexp_replace(s,'[[:space:]]',''),
        q'~^wwv_imp_util[.]get_subscription_id\([0-9]+,[0-9]+,'[A-Za-z0-9_-]+',[0-9]+([.][0-9]+)?\)$~','i') then
        return 'SUBSCRIPTION:'||regexp_replace(s,'[[:space:]]','');
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
        when 'create_flow' then 'APPLICATION' when 'create_acl_role' then 'ACL_ROLE'
        when 'create_theme' then 'THEME' when 'create_user_interface' then 'USER_INTERFACE' when 'create_template' then 'PAGE_TEMPLATE'
        when 'create_plug_template' then 'REGION_TEMPLATE'
        when 'create_field_template' then 'ITEM_TEMPLATE'
        when 'create_button_templates' then 'BUTTON_TEMPLATE'
        when 'create_template_option' then 'TEMPLATE_OPTION' else null end;
    end;
  begin
    if p_source is null or l_size=0 then reject('Empty application export'); end if;
    loop
      l_token:=token; exit when l_token.txt is null;
      if l_token.txt in ('wwv_flow_imp_page','wwv_flow_imp_shared','wwv_flow_imp','wwv_imp_workspace') then
        l_prefix:=l_token.txt;l_call_first:=l_token.first_pos; l_token:=token;
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
            if l_kind='APPLICATION' then
              l_span:=l_spans.get_object('p_id');
              if l_span.get_string('raw') is null or lower(regexp_replace(l_span.get_string('raw'),'[[:space:]]',''))!='wwv_flow.g_flow_id' then
                reject('Unsupported generated application identity');end if;
              -- Singleton context only. GET_INFO separately validates the real app ID.
              l_id:='0';
            end if;
            if not regexp_like(l_id,'^[0-9]+$') then reject('Unsupported component ID expression'); end if;
            if l_kind='PAGE' then l_page:=to_number(l_id); end if;
            l_component.put('kind',l_kind); l_component.put('call',l_call);
            l_component.put('id',l_id);
            if l_kind in ('PAGE','REGION','ITEM','BUTTON') then l_component.put('page',l_page);
            else l_component.put('page',0); end if;
            l_component.put('name',coalesce(l_attrs.get_string('p_name'),l_attrs.get_string('p_template_name'),l_attrs.get_string('p_page_plug_template_name'),l_attrs.get_string('p_plug_name'),l_attrs.get_string('p_button_name'),l_attrs.get_string('p_theme_name'),l_id));
            l_component.put('parent',coalesce(l_attrs.get_string('p_item_plug_id'),l_attrs.get_string('p_plug_id'),l_attrs.get_string('p_button_plug_id'),l_attrs.get_string('p_parent_plug_id'),'#NULL#'));
            l_key:=l_kind||':'||l_component.get_number('page')||':'||l_id;
            if l_seen.exists(l_key) then reject('Duplicate component identity'); end if;
            l_seen(l_key):=true;
            l_component.put('key',l_key); l_component.put('attrs',l_attrs); l_component.put('spans',l_spans);
            if l_kind in ('THEME','USER_INTERFACE','PAGE_TEMPLATE','REGION_TEMPLATE','ITEM_TEMPLATE','BUTTON_TEMPLATE') then
              dbms_lob.createtemporary(l_definition,true);
              if l_kind='THEME' and l_spans.has('p_files_version') then
                -- This generated cache-busting counter changes on an APEXlang
                -- import without changing theme semantics. Ignore only its span
                -- in context hashing; full artifact/freshness hashes retain it.
                l_span:=l_spans.get_object('p_files_version');
                dbms_lob.copy(l_definition,p_source,l_span.get_number('start')-l_call_first,1,l_call_first);
                dbms_lob.writeappend(l_definition,1,'0');
                dbms_lob.copy(l_definition,p_source,l_token.last_pos-l_span.get_number('end'),dbms_lob.getlength(l_definition)+1,l_span.get_number('end')+1);
              else dbms_lob.copy(l_definition,p_source,l_token.last_pos-l_call_first+1,1,l_call_first);end if;
              l_component.put('definition_hash',rawtohex(dbms_crypto.hash(l_definition,dbms_crypto.hash_sh256)));
              dbms_lob.freetemporary(l_definition);
            end if;
            l_result.append(l_component);
          end if;
        end if;
      end if;
    end loop;
    if l_result.get_size=0 then reject('No recognized components in export'); end if;
    return l_result;
  exception when others then
    if dbms_lob.istemporary(l_definition)=1 then dbms_lob.freetemporary(l_definition);end if;raise;
  end;

  function acl_fingerprint(p_source clob) return varchar2 is
    type t_hashes is table of varchar2(64) index by varchar2(4000);
    hashes t_hashes;a json_array_t:=parse(p_source);o json_object_t;v json_object_t;
    spans json_object_t;s json_object_t;key varchar2(4000);piece clob;
    h varchar2(64):=rawtohex(dbms_crypto.hash(utl_i18n.string_to_raw('APXTM ACL v1','AL32UTF8'),dbms_crypto.hash_sh256));
  begin
    for i in 0..a.get_size-1 loop
      o:=treat(a.get(i) as json_object_t);
      if o.get_string('kind')='ACL_ROLE' then
        v:=o.get_object('attrs');spans:=o.get_object('spans');key:=v.get_string('p_static_id');
        if key is null or key in ('#EXPR#','#NULL#','#EMPTY#') or not spans.has('p_users') then
          reject('ACL assignment export is outside the supported restore format');end if;
        if hashes.exists(key) then reject('Duplicate ACL role static identity');end if;
        s:=spans.get_object('p_users');dbms_lob.createtemporary(piece,true);
        dbms_lob.copy(piece,p_source,s.get_number('end')-s.get_number('start')+1,1,s.get_number('start'));
        hashes(key):=rawtohex(dbms_crypto.hash(piece,dbms_crypto.hash_sh256));dbms_lob.freetemporary(piece);
      end if;
    end loop;
    key:=hashes.first;
    while key is not null loop
      h:=rawtohex(dbms_crypto.hash(utl_i18n.string_to_raw(h||':'||length(key)||':'||key||':'||hashes(key),'AL32UTF8'),dbms_crypto.hash_sh256));
      key:=hashes.next(key);
    end loop;
    return h;
  exception when others then if dbms_lob.istemporary(piece)=1 then dbms_lob.freetemporary(piece);end if;raise;
  end;

  function patch(p_source clob,p_changes json_array_t) return clob is
    type t_edit is record(last_pos pls_integer,value varchar2(4000));
    type t_edits is table of t_edit index by pls_integer;
    type t_groups is table of boolean index by varchar2(1000);
    l_edits t_edits;
    l_groups t_groups;
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

    function grid_group(p_kind varchar2,p_page number,p_parent varchar2,p_position varchar2) return varchar2 is
    begin
      return p_kind||':'||p_page||':'||p_parent||':'||case when p_kind='BUTTON' then p_position end;
    end;

    procedure validate_grid(p_components json_array_t) is
      type t_cells is table of varchar2(512) index by pls_integer;
      cells t_cells;doc clob;group_id varchar2(1000);previous_group varchar2(1000);
      column_no number;span_no number;known_row boolean:=true;
    begin
      doc:=p_components.to_clob;
      -- BODY buttons share the item grid. This beta does not model arbitrary
      -- interleaved mixed rows. Permit only known trailing button rows that
      -- cannot share a row with an item; reject the remaining arrangements.
      for mixed in (
        select page_id,parent_id,
          sum(case when not regexp_like(display_sequence,'^[0-9]{1,12}$') or display_sequence is null then 1 else 0 end) unknown_sequences,
          max(case when kind='ITEM' and regexp_like(display_sequence,'^[0-9]{1,12}$') then to_number(display_sequence) end) last_item,
          min(case when kind='BUTTON' and regexp_like(display_sequence,'^[0-9]{1,12}$') then to_number(display_sequence) end) first_button,
          sum(case when kind='BUTTON' and (nvl(new_row,'Y') not in ('Y','TRUE') or nvl(new_column,'Y')!='Y') then 1 else 0 end) shared_button_rows
        from (
          select j.*,case kind when 'ITEM' then item_sequence else button_sequence end display_sequence
          from json_table(doc,'$[*]' columns(
            kind varchar2(30) path '$.kind',page_id number path '$.page',parent_id varchar2(256) path '$.parent',
            button_position varchar2(256) path '$.attrs.p_button_position',item_sequence varchar2(128) path '$.attrs.p_item_sequence',
            button_sequence varchar2(128) path '$.attrs.p_button_sequence',new_row varchar2(128) path '$.attrs.p_grid_new_row',
            new_column varchar2(128) path '$.attrs.p_grid_new_column')) j
          where kind='ITEM' or (kind='BUTTON' and nvl(button_position,'BODY')='BODY')
        ) group by page_id,parent_id
        having count(case when kind='ITEM' then 1 end)>0 and count(case when kind='BUTTON' then 1 end)>0
      ) loop
        if l_groups.exists(grid_group('ITEM',mixed.page_id,mixed.parent_id,null))
          or l_groups.exists(grid_group('BUTTON',mixed.page_id,mixed.parent_id,null))
          or l_groups.exists(grid_group('BUTTON',mixed.page_id,mixed.parent_id,'BODY')) then
          if mixed.unknown_sequences>0 or mixed.first_button<=mixed.last_item or mixed.shared_button_rows>0 then
            reject('Mixed item/BODY-button rows require manual review; only known trailing new-row buttons are supported.');
          end if;
        end if;
      end loop;
      for r in (
        select j.*,
          case kind when 'REGION' then coalesce(grid_column,plug_column) else grid_column end effective_column,
          case kind when 'REGION' then coalesce(plug_span,grid_span) when 'ITEM' then item_span else grid_span end effective_span,
          case kind when 'REGION' then nvl(plug_new_row,'TRUE') when 'ITEM' then nvl(item_new_row,'Y') else nvl(button_new_row,'Y') end new_row,
          case kind when 'ITEM' then nvl(item_new_field,'Y') when 'BUTTON' then nvl(button_new_field,'Y') else 'Y' end new_field,
          case kind when 'REGION' then plug_sequence when 'ITEM' then item_sequence else button_sequence end display_sequence
        from json_table(doc,'$[*]' columns(
          component_key varchar2(512) path '$.key',kind varchar2(30) path '$.kind',page_id number path '$.page',
          parent_id varchar2(256) path '$.parent',button_position varchar2(256) path '$.attrs.p_button_position',
          grid_column varchar2(128) path '$.attrs.p_grid_column',plug_column varchar2(128) path '$.attrs.p_plug_display_column',
          plug_span varchar2(128) path '$.attrs.p_plug_grid_column_span',grid_span varchar2(128) path '$.attrs.p_grid_column_span',
          item_span varchar2(128) path '$.attrs.p_colspan',plug_new_row varchar2(128) path '$.attrs.p_plug_new_grid_row',
          item_new_row varchar2(128) path '$.attrs.p_begin_on_new_line',button_new_row varchar2(128) path '$.attrs.p_grid_new_row',
          item_new_field varchar2(128) path '$.attrs.p_begin_on_new_field',button_new_field varchar2(128) path '$.attrs.p_grid_new_column',
          plug_sequence varchar2(128) path '$.attrs.p_plug_display_sequence',item_sequence varchar2(128) path '$.attrs.p_item_sequence',
          button_sequence varchar2(128) path '$.attrs.p_button_sequence')) j
        where kind in ('REGION','ITEM','BUTTON')
        order by kind,page_id,parent_id,button_position,
          case when regexp_like(case kind when 'REGION' then plug_sequence when 'ITEM' then item_sequence else button_sequence end,'^[0-9]{1,12}$')
            then to_number(case kind when 'REGION' then plug_sequence when 'ITEM' then item_sequence else button_sequence end) end,
          component_key
      ) loop
        group_id:=grid_group(r.kind,r.page_id,r.parent_id,r.button_position);
        if l_groups.exists(group_id) then
          if previous_group is null or previous_group!=group_id then cells.delete;known_row:=true;end if;
          previous_group:=group_id;
          -- Omitted new-row defaults were independently observed as true on
          -- the tested 26.2 export. This validates a plan; it inserts no default.
          if r.new_row in ('Y','TRUE') then cells.delete;known_row:=true;
          elsif r.new_row not in ('N','FALSE') then known_row:=false;end if;
          if r.display_sequence is null or not regexp_like(r.display_sequence,'^[0-9]{1,12}$')
            or r.new_field not in ('Y','N') then known_row:=false;end if;
          if regexp_like(r.effective_column,'^[0-9]{1,2}$') and regexp_like(r.effective_span,'^[0-9]{1,2}$') then
            column_no:=to_number(r.effective_column);span_no:=to_number(r.effective_span);
            if column_no between 1 and 12 and span_no between 1 and 12 then
              if column_no+span_no-1>12 then
                reject('Selected changes exceed the twelve-column grid; include the related column/span corrections.');end if;
              if known_row and r.new_field='Y' then
                for pos in column_no..column_no+span_no-1 loop
                  if cells.exists(pos) then reject('Selected changes overlap sibling grid columns; include the related column/span corrections.');end if;
                  cells(pos):=r.component_key;
                end loop;
              end if;
            else known_row:=false;end if;
          else known_row:=false;end if;
        end if;
      end loop;
      if dbms_lob.istemporary(doc)=1 then dbms_lob.freetemporary(doc);end if;
    exception when others then if dbms_lob.istemporary(doc)=1 then dbms_lob.freetemporary(doc);end if;raise;
    end;
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
          l_groups(grid_group(l_component.get_string('kind'),l_component.get_number('page'),l_component.get_string('parent'),l_attrs.get_string('p_button_position'))):=true;
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
    validate_grid(l_components);
    return l_result;
  exception when others then
    if dbms_lob.istemporary(l_result)=1 then dbms_lob.freetemporary(l_result); end if;
    raise;
  end;
end apxtm_parse;
/
