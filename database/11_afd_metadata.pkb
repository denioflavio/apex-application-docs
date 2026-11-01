create or replace package body afd_metadata as
    function is_allowed return boolean is
        l_count number;
    begin
        if apex_application.g_user is null or upper(apex_application.g_user) in ('NOBODY','APEX_PUBLIC_USER') then
            return false;
        end if;
        select count(*) into l_count from afd_allowed_users
         where username = upper(apex_application.g_user);
        return l_count = 1 and to_number(sys_context('APEX$SESSION','WORKSPACE_ID')) > 0;
    end;

    procedure assert_access(p_application_id number default null, p_page_id number default null) is
        l_count number;
    begin
        if not is_allowed then raise_application_error(-20001, 'Documentation access denied.'); end if;
        if p_application_id is not null then
            select count(*) into l_count from apex_applications
             where application_id = p_application_id
               and workspace_id = to_number(sys_context('APEX$SESSION','WORKSPACE_ID'));
            if l_count != 1 then raise_application_error(-20002, 'Application is not available in this workspace.'); end if;
        end if;
        if p_page_id is not null then
            select count(*) into l_count from apex_application_pages p
             join apex_applications a on a.application_id = p.application_id
             where p.application_id = p_application_id and p.page_id = p_page_id
               and a.workspace_id = to_number(sys_context('APEX$SESSION','WORKSPACE_ID'));
            if l_count != 1 then raise_application_error(-20003, 'Page is not available in this application.'); end if;
        end if;
    end;

    function document(p_application_id number) return clob is
        l_doc json_object_t := json_object_t();
        l_components json_array_t := json_array_t();
        l_pages json_array_t := json_array_t();
        l_coverage json_array_t := json_array_t();
        l_scope json_object_t := json_object_t();
        l_app json_object_t;
        l_workspace varchar2(255);
        l_version varchar2(100);
        l_json clob;
        l_cursor sys_refcursor;
        l_page json_object_t;
        l_raw json_object_t;

        procedure add_family(p_family varchar2, p_view varchar2, p_id varchar2,
            p_name varchar2, p_sequence varchar2, p_static varchar2,
            p_sources varchar2, p_sql varchar2) is
            c sys_refcursor;
            raw_json clob;
            props json_object_t;
            node json_object_t;
            srcs json_array_t;
            refs json_array_t;
            src json_object_t;
            ref_obj json_object_t;
            origin json_object_t;
            keys json_key_list;
            source_keys apex_t_varchar2;
            source_text clob;
            identifier varchar2(200);
            key_name varchar2(128);
            kind varchar2(30);
            attrs json_element_t;
        begin
            open c for p_sql using p_application_id, l_workspace;
            loop
                fetch c into raw_json;
                exit when c%notfound;
                props := json_object_t.parse(raw_json);
                node := json_object_t();
                identifier := props.get_string(p_id);
                node.put('key', p_family || '-' || identifier);
                node.put('id', identifier);
                node.put('family', p_family);
                node.put('name', props.get_string(p_name));
                if props.has('PAGE_ID') then node.put('pageId', props.get_number('PAGE_ID')); end if;
                if p_static is not null then node.put('staticId', props.get_string(p_static)); end if;
                if p_sequence is not null then node.put('sequence', props.get_number(p_sequence)); end if;
                node.put('comment', props.get_string('COMPONENT_COMMENT'));
                origin := json_object_t();
                origin.put('view', p_view);
                origin.put('idColumn', p_id);
                node.put('origin', origin);
                srcs := json_array_t();
                source_keys := apex_string.split(p_sources, ',');
                for i in 1 .. source_keys.count loop
                    key_name := source_keys(i);
                    source_text := props.get_clob(key_name);
                    if source_text is not null and dbms_lob.getlength(source_text) > 0 then
                        src := json_object_t();
                        src.put('column', key_name);
                        src.put('language', case
                            when p_family = 'process' then lower(nvl(props.get_string('PROCESS_SOURCE_LANGUAGE'),case when props.get_string('PROCESS_TYPE_PLUGIN_STATIC_ID')='NATIVE_PLSQL' then 'plsql' else 'text' end))
                            when p_family = 'region' and props.get_string('SOURCE_TYPE_PLUGIN_STATIC_ID') in ('NATIVE_IR','NATIVE_SQL_REPORT','NATIVE_IG') then 'sql'
                            when p_family = 'region' and props.get_string('SOURCE_TYPE_PLUGIN_STATIC_ID') = 'NATIVE_DYNAMIC_CONTENT' then 'plsql'
                            else 'text' end);
                        src.put('text', source_text);
                        srcs.append(src);
                    end if;
                end loop;
                attrs := props.get('ATTRIBUTES');
                if attrs is not null and attrs.is_string then
                    source_text := props.get_clob('ATTRIBUTES');
                    if substr(ltrim(source_text),1,1) = '{' then
                        props.put('ATTRIBUTES', json_object_t.parse(source_text));
                    end if;
                end if;
                kind := case when srcs.get_size > 0 then 'textual'
                    when p_sources is null then 'declarative'
                    when props.has('ATTRIBUTES') and not props.get('ATTRIBUTES').is_null then 'declarative'
                    else 'notProvided' end;
                node.put('sourceKind', kind);
                node.put('sources', srcs);
                refs := json_array_t();
                keys := props.get_keys;
                for i in 1 .. keys.count loop
                    key_name := keys(i);
                    if (key_name like '%\_ID' escape '\' or key_name in ('ASSOCIATED_ITEM','WHEN_ELEMENT','AFFECTED_ELEMENTS','AJAX_ITEMS_TO_SUBMIT'))
                       and key_name not in (p_id,nvl(p_static,'STATIC_ID'),'STATIC_ID','APPLICATION_ID','PAGE_ID')
                       and not props.get(key_name).is_null then
                        ref_obj := json_object_t();
                        ref_obj.put('property', key_name);
                        ref_obj.put('value', props.get(key_name));
                        ref_obj.put('kind','declared');
                        refs.append(ref_obj);
                    end if;
                end loop;
                node.put('references', refs);
                node.put('properties', props);
                l_components.append(node);
            end loop;
            close c;
            l_coverage.append(p_family);
        exception
            when others then
                if c%isopen then close c; end if;
                raise;
        end;
    begin
        assert_access(p_application_id);
        select workspace, json_object('APPLICATION_ID' value application_id,
            'APPLICATION_NAME' value application_name, 'ALIAS' value alias,
            'OWNER' value owner, 'WORKSPACE' value workspace,
            'APPLICATION_COMMENT' value application_comment,
            'AUTHENTICATION_SCHEME' value authentication_scheme,
            'AUTHORIZATION_SCHEME' value authorization_scheme,
            'AUTHORIZATION_SCHEME_ID' value authorization_scheme_id,
            'GLOBAL_PAGE_ID' value global_page_id returning clob)
          into l_workspace, l_json from apex_applications
         where application_id = p_application_id and workspace_id = to_number(sys_context('APEX$SESSION','WORKSPACE_ID'));
        l_app := json_object_t.parse(l_json);
        for p in (select page_id, page_name, page_mode, page_function, page_comment,
                         authorization_scheme, authorization_scheme_id, page_group
                    from apex_application_pages where application_id = p_application_id
                      and workspace = l_workspace order by page_id) loop
            l_page := json_object_t();
            l_page.put('pageId',p.page_id);
            l_page.put('name',p.page_name);
            l_page.put('mode',p.page_mode);
            l_page.put('function',p.page_function);
            l_page.put('group',p.page_group);
            l_page.put('comment',p.page_comment);
            l_page.put('authorization',p.authorization_scheme);
            l_page.put('authorizationId',p.authorization_scheme_id);
            l_page.put('origin','APEX_APPLICATION_PAGES');
            l_pages.append(l_page);
        end loop;
        add_family(q'~region~', q'~APEX_APPLICATION_PAGE_REGIONS~', q'~REGION_ID~', q'~REGION_NAME~', q'~DISPLAY_SEQUENCE~', q'~REGION_STATIC_ID~', q'~REGION_SOURCE~', q'~select json_object('APPLICATION_ID' value t.APPLICATION_ID,'PAGE_ID' value t.PAGE_ID,'STATIC_ID' value t.STATIC_ID,'COMPONENT_COMMENT' value t.COMPONENT_COMMENT,'AUTHORIZATION_SCHEME' value t.AUTHORIZATION_SCHEME,'AUTHORIZATION_SCHEME_ID' value t.AUTHORIZATION_SCHEME_ID,'CONDITION_TYPE' value t.CONDITION_TYPE,'CONDITION_TYPE_CODE' value t.CONDITION_TYPE_CODE,'CONDITION_EXPRESSION1' value t.CONDITION_EXPRESSION1,'CONDITION_EXPRESSION2' value t.CONDITION_EXPRESSION2,'BUILD_OPTION' value t.BUILD_OPTION,'LAST_UPDATED_ON' value t.LAST_UPDATED_ON,'REGION_ID' value t.REGION_ID,'REGION_NAME' value t.REGION_NAME,'DISPLAY_SEQUENCE' value t.DISPLAY_SEQUENCE,'REGION_STATIC_ID' value t.REGION_STATIC_ID,'REGION_SOURCE' value t.REGION_SOURCE,'SOURCE_TYPE_PLUGIN_STATIC_ID' value t.SOURCE_TYPE_PLUGIN_STATIC_ID,'SOURCE_TYPE' value t.SOURCE_TYPE,'PARENT_REGION_ID' value t.PARENT_REGION_ID,'MASTER_REGION_ID' value t.MASTER_REGION_ID,'ATTRIBUTES' value t.ATTRIBUTES,'QUERY_TYPE' value t.QUERY_TYPE,'TABLE_OWNER' value t.TABLE_OWNER,'TABLE_NAME' value t.TABLE_NAME,'WHERE_CLAUSE' value t.WHERE_CLAUSE,'ORDER_BY_CLAUSE' value t.ORDER_BY_CLAUSE,'AJAX_ITEMS_TO_SUBMIT' value t.AJAX_ITEMS_TO_SUBMIT returning clob) from APEX_APPLICATION_PAGE_REGIONS t where t.application_id = :app_id and t.workspace = :workspace order by t.PAGE_ID,t.DISPLAY_SEQUENCE,t.REGION_ID~');
        add_family(q'~item~', q'~APEX_APPLICATION_PAGE_ITEMS~', q'~ITEM_ID~', q'~ITEM_NAME~', q'~DISPLAY_SEQUENCE~', q'~~', q'~ITEM_SOURCE~', q'~select json_object('APPLICATION_ID' value t.APPLICATION_ID,'PAGE_ID' value t.PAGE_ID,'COMPONENT_COMMENT' value t.COMPONENT_COMMENT,'AUTHORIZATION_SCHEME' value t.AUTHORIZATION_SCHEME,'AUTHORIZATION_SCHEME_ID' value t.AUTHORIZATION_SCHEME_ID,'CONDITION_TYPE' value t.CONDITION_TYPE,'CONDITION_TYPE_CODE' value t.CONDITION_TYPE_CODE,'CONDITION_EXPRESSION1' value t.CONDITION_EXPRESSION1,'CONDITION_EXPRESSION2' value t.CONDITION_EXPRESSION2,'BUILD_OPTION' value t.BUILD_OPTION,'LAST_UPDATED_ON' value t.LAST_UPDATED_ON,'ITEM_ID' value t.ITEM_ID,'ITEM_NAME' value t.ITEM_NAME,'DISPLAY_SEQUENCE' value t.DISPLAY_SEQUENCE,'ITEM_SOURCE' value t.ITEM_SOURCE,'DISPLAY_AS' value t.DISPLAY_AS,'DISPLAY_AS_CODE' value t.DISPLAY_AS_CODE,'LABEL' value t.LABEL,'REGION_ID' value t.REGION_ID,'ITEM_DEFAULT' value t.ITEM_DEFAULT,'LOV_DEFINITION' value t.LOV_DEFINITION,'LOV_NAMED_LOV' value t.LOV_NAMED_LOV,'LOV_DISPLAY_NULL' value t.LOV_DISPLAY_NULL,'ATTRIBUTES' value t.ATTRIBUTES returning clob) from APEX_APPLICATION_PAGE_ITEMS t where t.application_id = :app_id and t.workspace = :workspace order by t.PAGE_ID,t.DISPLAY_SEQUENCE,t.ITEM_ID~');
        add_family(q'~button~', q'~APEX_APPLICATION_PAGE_BUTTONS~', q'~BUTTON_ID~', q'~BUTTON_NAME~', q'~BUTTON_SEQUENCE~', q'~BUTTON_STATIC_ID~', q'~~', q'~select json_object('APPLICATION_ID' value t.APPLICATION_ID,'PAGE_ID' value t.PAGE_ID,'STATIC_ID' value t.STATIC_ID,'COMPONENT_COMMENT' value t.COMPONENT_COMMENT,'AUTHORIZATION_SCHEME' value t.AUTHORIZATION_SCHEME,'AUTHORIZATION_SCHEME_ID' value t.AUTHORIZATION_SCHEME_ID,'CONDITION_TYPE' value t.CONDITION_TYPE,'CONDITION_TYPE_CODE' value t.CONDITION_TYPE_CODE,'CONDITION_EXPRESSION1' value t.CONDITION_EXPRESSION1,'CONDITION_EXPRESSION2' value t.CONDITION_EXPRESSION2,'BUILD_OPTION' value t.BUILD_OPTION,'LAST_UPDATED_ON' value t.LAST_UPDATED_ON,'BUTTON_ID' value t.BUTTON_ID,'BUTTON_NAME' value t.BUTTON_NAME,'BUTTON_SEQUENCE' value t.BUTTON_SEQUENCE,'BUTTON_STATIC_ID' value t.BUTTON_STATIC_ID,'LABEL' value t.LABEL,'REGION_ID' value t.REGION_ID,'BUTTON_ACTION' value t.BUTTON_ACTION,'BUTTON_ACTION_CODE' value t.BUTTON_ACTION_CODE,'REDIRECT_URL' value t.REDIRECT_URL,'EXECUTE_VALIDATIONS' value t.EXECUTE_VALIDATIONS,'DATABASE_ACTION' value t.DATABASE_ACTION returning clob) from APEX_APPLICATION_PAGE_BUTTONS t where t.application_id = :app_id and t.workspace = :workspace order by t.PAGE_ID,t.BUTTON_SEQUENCE,t.BUTTON_ID~');
        add_family(q'~validation~', q'~APEX_APPLICATION_PAGE_VAL~', q'~VALIDATION_ID~', q'~VALIDATION_NAME~', q'~VALIDATION_SEQUENCE~', q'~STATIC_ID~', q'~VALIDATION_EXPRESSION1,VALIDATION_EXPRESSION2~', q'~select json_object('APPLICATION_ID' value t.APPLICATION_ID,'PAGE_ID' value t.PAGE_ID,'STATIC_ID' value t.STATIC_ID,'COMPONENT_COMMENT' value t.COMPONENT_COMMENT,'AUTHORIZATION_SCHEME' value t.AUTHORIZATION_SCHEME,'AUTHORIZATION_SCHEME_ID' value t.AUTHORIZATION_SCHEME_ID,'CONDITION_TYPE' value t.CONDITION_TYPE,'CONDITION_TYPE_CODE' value t.CONDITION_TYPE_CODE,'CONDITION_EXPRESSION1' value t.CONDITION_EXPRESSION1,'CONDITION_EXPRESSION2' value t.CONDITION_EXPRESSION2,'BUILD_OPTION' value t.BUILD_OPTION,'LAST_UPDATED_ON' value t.LAST_UPDATED_ON,'VALIDATION_ID' value t.VALIDATION_ID,'VALIDATION_NAME' value t.VALIDATION_NAME,'VALIDATION_SEQUENCE' value t.VALIDATION_SEQUENCE,'VALIDATION_EXPRESSION1' value t.VALIDATION_EXPRESSION1,'VALIDATION_EXPRESSION2' value t.VALIDATION_EXPRESSION2,'VALIDATION_TYPE' value t.VALIDATION_TYPE,'VALIDATION_TYPE_CODE' value t.VALIDATION_TYPE_CODE,'REGION_ID' value t.REGION_ID,'WHEN_BUTTON_PRESSED' value t.WHEN_BUTTON_PRESSED,'WHEN_BUTTON_PRESSED_ID' value t.WHEN_BUTTON_PRESSED_ID,'ASSOCIATED_ITEM' value t.ASSOCIATED_ITEM,'ASSOCIATED_COLUMN' value t.ASSOCIATED_COLUMN,'VALIDATION_FAILURE_TEXT' value t.VALIDATION_FAILURE_TEXT,'ALWAYS_EXECUTE' value t.ALWAYS_EXECUTE returning clob) from APEX_APPLICATION_PAGE_VAL t where t.application_id = :app_id and t.workspace = :workspace order by t.PAGE_ID,t.VALIDATION_SEQUENCE,t.VALIDATION_ID~');
        add_family(q'~process~', q'~APEX_APPLICATION_PAGE_PROC~', q'~PROCESS_ID~', q'~PROCESS_NAME~', q'~EXECUTION_SEQUENCE~', q'~STATIC_ID~', q'~PROCESS_SOURCE~', q'~select json_object('APPLICATION_ID' value t.APPLICATION_ID,'PAGE_ID' value t.PAGE_ID,'STATIC_ID' value t.STATIC_ID,'COMPONENT_COMMENT' value t.COMPONENT_COMMENT,'AUTHORIZATION_SCHEME' value t.AUTHORIZATION_SCHEME,'AUTHORIZATION_SCHEME_ID' value t.AUTHORIZATION_SCHEME_ID,'CONDITION_TYPE' value t.CONDITION_TYPE,'CONDITION_TYPE_CODE' value t.CONDITION_TYPE_CODE,'CONDITION_EXPRESSION1' value t.CONDITION_EXPRESSION1,'CONDITION_EXPRESSION2' value t.CONDITION_EXPRESSION2,'BUILD_OPTION' value t.BUILD_OPTION,'LAST_UPDATED_ON' value t.LAST_UPDATED_ON,'PROCESS_ID' value t.PROCESS_ID,'PROCESS_NAME' value t.PROCESS_NAME,'EXECUTION_SEQUENCE' value t.EXECUTION_SEQUENCE,'PROCESS_SOURCE' value t.PROCESS_SOURCE,'PROCESS_TYPE_PLUGIN_STATIC_ID' value t.PROCESS_TYPE_PLUGIN_STATIC_ID,'PROCESS_TYPE' value t.PROCESS_TYPE,'PROCESS_POINT' value t.PROCESS_POINT,'PROCESS_POINT_CODE' value t.PROCESS_POINT_CODE,'EXECUTION_CHAIN_ID' value t.EXECUTION_CHAIN_ID,'PROCESS_SOURCE_LANGUAGE' value t.PROCESS_SOURCE_LANGUAGE,'REGION_ID' value t.REGION_ID,'WHEN_BUTTON_PRESSED' value t.WHEN_BUTTON_PRESSED,'WHEN_BUTTON_PRESSED_ID' value t.WHEN_BUTTON_PRESSED_ID,'RUN_PROCESS' value t.RUN_PROCESS,'ATTRIBUTES' value t.ATTRIBUTES returning clob) from APEX_APPLICATION_PAGE_PROC t where t.application_id = :app_id and t.workspace = :workspace order by t.PAGE_ID,t.EXECUTION_SEQUENCE,t.PROCESS_ID~');
        add_family(q'~branch~', q'~APEX_APPLICATION_PAGE_BRANCHES~', q'~BRANCH_ID~', q'~BRANCH_NAME~', q'~PROCESS_SEQUENCE~', q'~~', q'~BRANCH_ACTION~', q'~select json_object('APPLICATION_ID' value t.APPLICATION_ID,'PAGE_ID' value t.PAGE_ID,'COMPONENT_COMMENT' value t.COMPONENT_COMMENT,'AUTHORIZATION_SCHEME' value t.AUTHORIZATION_SCHEME,'AUTHORIZATION_SCHEME_ID' value t.AUTHORIZATION_SCHEME_ID,'CONDITION_TYPE' value t.CONDITION_TYPE,'CONDITION_TYPE_CODE' value t.CONDITION_TYPE_CODE,'CONDITION_EXPRESSION1' value t.CONDITION_EXPRESSION1,'CONDITION_EXPRESSION2' value t.CONDITION_EXPRESSION2,'BUILD_OPTION' value t.BUILD_OPTION,'LAST_UPDATED_ON' value t.LAST_UPDATED_ON,'BRANCH_ID' value t.BRANCH_ID,'BRANCH_NAME' value t.BRANCH_NAME,'PROCESS_SEQUENCE' value t.PROCESS_SEQUENCE,'BRANCH_ACTION' value t.BRANCH_ACTION,'BRANCH_TYPE' value t.BRANCH_TYPE,'BRANCH_POINT' value t.BRANCH_POINT,'BRANCH_LANGUAGE' value t.BRANCH_LANGUAGE,'WHEN_BUTTON_PRESSED' value t.WHEN_BUTTON_PRESSED,'BRANCH_WHEN_BUTTON_ID' value t.BRANCH_WHEN_BUTTON_ID returning clob) from APEX_APPLICATION_PAGE_BRANCHES t where t.application_id = :app_id and t.workspace = :workspace order by t.PAGE_ID,t.PROCESS_SEQUENCE,t.BRANCH_ID~');
        add_family(q'~dynamicAction~', q'~APEX_APPLICATION_PAGE_DA~', q'~DYNAMIC_ACTION_ID~', q'~DYNAMIC_ACTION_NAME~', q'~DYNAMIC_ACTION_SEQUENCE~', q'~STATIC_ID~', q'~~', q'~select json_object('APPLICATION_ID' value t.APPLICATION_ID,'PAGE_ID' value t.PAGE_ID,'STATIC_ID' value t.STATIC_ID,'COMPONENT_COMMENT' value t.COMPONENT_COMMENT,'AUTHORIZATION_SCHEME' value t.AUTHORIZATION_SCHEME,'AUTHORIZATION_SCHEME_ID' value t.AUTHORIZATION_SCHEME_ID,'CONDITION_TYPE' value t.CONDITION_TYPE,'CONDITION_TYPE_CODE' value t.CONDITION_TYPE_CODE,'CONDITION_EXPRESSION1' value t.CONDITION_EXPRESSION1,'CONDITION_EXPRESSION2' value t.CONDITION_EXPRESSION2,'BUILD_OPTION' value t.BUILD_OPTION,'LAST_UPDATED_ON' value t.LAST_UPDATED_ON,'DYNAMIC_ACTION_ID' value t.DYNAMIC_ACTION_ID,'DYNAMIC_ACTION_NAME' value t.DYNAMIC_ACTION_NAME,'DYNAMIC_ACTION_SEQUENCE' value t.DYNAMIC_ACTION_SEQUENCE,'WHEN_EVENT_NAME' value t.WHEN_EVENT_NAME,'WHEN_EVENT_INTERNAL_NAME' value t.WHEN_EVENT_INTERNAL_NAME,'WHEN_EVENT_CUSTOM_NAME' value t.WHEN_EVENT_CUSTOM_NAME,'WHEN_SELECTION_TYPE' value t.WHEN_SELECTION_TYPE,'WHEN_ELEMENT' value t.WHEN_ELEMENT,'WHEN_BUTTON' value t.WHEN_BUTTON,'WHEN_BUTTON_ID' value t.WHEN_BUTTON_ID,'WHEN_REGION_ID' value t.WHEN_REGION_ID,'WHEN_CONDITION' value t.WHEN_CONDITION,'WHEN_EXPRESSION' value t.WHEN_EXPRESSION,'WHEN_EVENT_SCOPE' value t.WHEN_EVENT_SCOPE returning clob) from APEX_APPLICATION_PAGE_DA t where t.application_id = :app_id and t.workspace = :workspace order by t.PAGE_ID,t.DYNAMIC_ACTION_SEQUENCE,t.DYNAMIC_ACTION_ID~');
        add_family(q'~dynamicActionAction~', q'~APEX_APPLICATION_PAGE_DA_ACTS~', q'~ACTION_ID~', q'~ACTION_NAME~', q'~ACTION_SEQUENCE~', q'~STATIC_ID~', q'~~', q'~select json_object('APPLICATION_ID' value t.APPLICATION_ID,'PAGE_ID' value t.PAGE_ID,'STATIC_ID' value t.STATIC_ID,'COMPONENT_COMMENT' value t.COMPONENT_COMMENT,'AUTHORIZATION_SCHEME' value t.AUTHORIZATION_SCHEME,'AUTHORIZATION_SCHEME_ID' value t.AUTHORIZATION_SCHEME_ID,'BUILD_OPTION' value t.BUILD_OPTION,'LAST_UPDATED_ON' value t.LAST_UPDATED_ON,'ACTION_ID' value t.ACTION_ID,'ACTION_NAME' value t.ACTION_NAME,'ACTION_SEQUENCE' value t.ACTION_SEQUENCE,'ACTION_CODE' value t.ACTION_CODE,'ACTION_PD_NAME' value t.ACTION_PD_NAME,'DYNAMIC_ACTION_ID' value t.DYNAMIC_ACTION_ID,'DYNAMIC_ACTION_EVENT_RESULT' value t.DYNAMIC_ACTION_EVENT_RESULT,'AFFECTED_ELEMENTS_TYPE' value t.AFFECTED_ELEMENTS_TYPE,'AFFECTED_ELEMENTS' value t.AFFECTED_ELEMENTS,'AFFECTED_REGION_ID' value t.AFFECTED_REGION_ID,'AFFECTED_BUTTON_ID' value t.AFFECTED_BUTTON_ID,'CLIENT_CONDITION_TYPE' value t.CLIENT_CONDITION_TYPE,'SERVER_CONDITION_TYPE' value t.SERVER_CONDITION_TYPE,'SERVER_CONDITION_EXPRESSION1' value t.SERVER_CONDITION_EXPRESSION1,'SERVER_CONDITION_EXPRESSION2' value t.SERVER_CONDITION_EXPRESSION2,'ATTRIBUTES' value t.ATTRIBUTES returning clob) from APEX_APPLICATION_PAGE_DA_ACTS t where t.application_id = :app_id and t.workspace = :workspace order by t.PAGE_ID,t.ACTION_SEQUENCE,t.ACTION_ID~');
        add_family(q'~authorization~', q'~APEX_APPLICATION_AUTHORIZATION~', q'~AUTHORIZATION_SCHEME_ID~', q'~AUTHORIZATION_SCHEME_NAME~', q'~~', q'~STATIC_ID~', q'~~', q'~select json_object('APPLICATION_ID' value t.APPLICATION_ID,'STATIC_ID' value t.STATIC_ID,'COMPONENT_COMMENT' value t.COMPONENT_COMMENT,'AUTHORIZATION_SCHEME_ID' value t.AUTHORIZATION_SCHEME_ID,'LAST_UPDATED_ON' value t.LAST_UPDATED_ON,'AUTHORIZATION_SCHEME_NAME' value t.AUTHORIZATION_SCHEME_NAME,'SCHEME_TYPE' value t.SCHEME_TYPE,'SCHEME_TYPE_CODE' value t.SCHEME_TYPE_CODE,'ATTRIBUTES' value t.ATTRIBUTES,'CACHING' value t.CACHING,'ERROR_MESSAGE' value t.ERROR_MESSAGE,'REFERENCED_SCHEME_ID' value t.REFERENCED_SCHEME_ID returning clob) from APEX_APPLICATION_AUTHORIZATION t where t.application_id = :app_id and t.workspace = :workspace order by t.AUTHORIZATION_SCHEME_ID~');
        select version_no into l_version from apex_release;
        l_scope.put('workspaceId',to_number(sys_context('APEX$SESSION','WORKSPACE_ID')));
        l_scope.put('workspace',l_workspace);
        l_scope.put('applicationId',p_application_id);
        l_doc.put('schemaVersion','1.0');
        l_doc.put('collectorVersion',c_version);
        l_doc.put('apexVersion',l_version);
        l_doc.put('capturedAtUtc',to_char(sys_extract_utc(systimestamp),'YYYY-MM-DD"T"HH24:MI:SS.FF3"Z"'));
        l_doc.put('scope',l_scope);
        l_doc.put('application',l_app);
        l_doc.put('pages',l_pages);
        l_doc.put('components',l_components);
        l_doc.put('coverage',l_coverage);
        l_doc.put('limitations','Declared configuration only; excludes recursive package bodies, full shared components and observed runtime execution. IDs are installation-local.');
        return l_doc.to_clob;
    end;

    function component(p_application_id number, p_page_id number, p_key varchar2) return clob is
        d json_object_t;
        a json_array_t;
        n json_object_t;
    begin
        assert_access(p_application_id,p_page_id);
        d := json_object_t.parse(document(p_application_id));
        a := d.get_array('components');
        for i in 0 .. a.get_size - 1 loop
            n := treat(a.get(i) as json_object_t);
            if n.get_string('key') = p_key and n.get_number('pageId') = p_page_id then return n.to_clob; end if;
        end loop;
        raise_application_error(-20004,'Component is not available on this page.');
    end;

    function application_list return catalog_rows pipelined is
        r catalog_row;
    begin
        assert_access;
        for a in (select application_id, application_name, owner, application_comment,
                         pages from apex_applications
                    where workspace_id = to_number(sys_context('APEX$SESSION','WORKSPACE_ID')) order by application_name, application_id) loop
            r.application_id := a.application_id;
            r.name := a.application_name;
            r.family := 'application';
            r.type_name := a.owner;
            r.description := a.application_comment;
            r.component_count := a.pages;
            pipe row(r);
        end loop;
        return;
    end;

    function page_list(p_application_id number) return catalog_rows pipelined is
        d json_object_t;
        a json_array_t;
        n json_object_t;
        r catalog_row;
    begin
        d := json_object_t.parse(document(p_application_id));
        a := d.get_array('pages');
        for i in 0 .. a.get_size - 1 loop
            n := treat(a.get(i) as json_object_t);
            r.application_id := p_application_id;
            r.page_id := n.get_number('pageId');
            r.name := n.get_string('name');
            r.type_name := case when r.page_id = 0 then 'Global page' else n.get_string('mode') end;
            r.description := n.get_string('comment');
            r.sort_order := r.page_id;
            pipe row(r);
        end loop;
        return;
    end;

    function component_list(p_application_id number, p_page_id number) return catalog_rows pipelined is
        d json_object_t;
        a json_array_t;
        n json_object_t;
        props json_object_t;
        r catalog_row;
    begin
        assert_access(p_application_id,p_page_id);
        d := json_object_t.parse(document(p_application_id));
        a := d.get_array('components');
        for i in 0 .. a.get_size - 1 loop
            n := treat(a.get(i) as json_object_t);
            if n.get_number('pageId') = p_page_id then
                r.application_id := p_application_id;
                r.page_id := p_page_id;
                r.component_key := n.get_string('key');
                r.name := n.get_string('name');
                r.family := n.get_string('family');
                r.type_name := n.get_string('sourceKind');
                r.description := n.get_string('comment');
                r.sort_order := n.get_number('sequence');
                pipe row(r);
            end if;
        end loop;
        return;
    end;
end afd_metadata;
/
