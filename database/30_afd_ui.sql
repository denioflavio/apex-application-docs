create or replace package afd_ui authid definer as
    function hero return clob;
    function application_summary(p_application_id number) return clob;
    function page_summary(p_application_id number,p_page_id number) return clob;
    function component_detail(p_application_id number,p_page_id number,p_key varchar2) return clob;
    procedure download_markdown(p_application_id number);
end afd_ui;
/
create or replace package body afd_ui as
    procedure append_escaped(p_result in out nocopy clob,p_text clob) is
        offset_value pls_integer := 1;
        chunk varchar2(32767);
    begin
        while offset_value <= nvl(dbms_lob.getlength(p_text),0) loop
            chunk := dbms_lob.substr(p_text,4000,offset_value);
            dbms_lob.append(p_result,to_clob(apex_escape.html(chunk)));
            offset_value := offset_value + length(chunk);
        end loop;
    end;
    procedure block_code(p_result in out nocopy clob,p_title varchar2,p_text clob,p_open boolean default false) is
    begin
        dbms_lob.append(p_result,to_clob('<details class="afd-code"' || case when p_open then ' open' end || '><summary>' || apex_escape.html(p_title) || '</summary><button type="button" class="t-Button t-Button--small afd-copy">Copy</button><pre><code>'));
        append_escaped(p_result,p_text);
        dbms_lob.append(p_result,to_clob('</code></pre></details>'));
    end;
    function hero return clob is
    begin
        afd_metadata.assert_access;
        return to_clob('<section class="afd-hero"><div><span class="afd-eyebrow">APEX APPLICATION DOCS · PART 1</span><h1>Your application, documented.</h1><p>Explore the definition behind each page. Keep the source, the context and the developer notes together.</p><div class="afd-tags"><span class="afd-badge">Live metadata</span><span class="afd-badge">Markdown export</span><span class="afd-badge">No AI required</span></div></div><div class="afd-hero-mark" aria-hidden="true"><span class="fa fa-book"></span></div></section>');
    end;
    function application_summary(p_application_id number) return clob is
        d json_object_t;
        a json_object_t;
        items json_array_t;
        node json_object_t;
        result clob;
    begin
        d := json_object_t.parse(afd_metadata.document(p_application_id));
        a := d.get_object('application');
        dbms_lob.createtemporary(result,true);
        dbms_lob.append(result,to_clob('<section class="afd-summary"><span class="afd-eyebrow">APPLICATION ' || p_application_id || '</span><h1>' || apex_escape.html(a.get_string('APPLICATION_NAME')) || '</h1><p>' || apex_escape.html(nvl(a.get_string('APPLICATION_COMMENT'),'No developer comment recorded for this application.')) || '</p><div class="afd-tags"><span class="afd-badge">' || apex_escape.html(a.get_string('OWNER')) || '</span><span class="afd-badge">APEX ' || apex_escape.html(d.get_string('apexVersion')) || '</span><span class="afd-badge">Declared configuration</span></div></section><p class="afd-note">Coverage: pages, regions, items, buttons, validations, processes, branches, dynamic actions and authorization definitions. Package bodies and other shared components are outside this version.</p>'));
        items := d.get_array('components');
        for i in 0 .. items.get_size-1 loop
            node := treat(items.get(i) as json_object_t);
            if node.get_string('family')='authorization' then
                block_code(result,'Authorization · ' || node.get_string('name'),node.get_object('properties').to_clob);
            end if;
        end loop;
        return result;
    end;
    function page_summary(p_application_id number,p_page_id number) return clob is
        d json_object_t;
        pages json_array_t;
        node json_object_t;
        result clob;
    begin
        afd_metadata.assert_access(p_application_id,p_page_id);
        d := json_object_t.parse(afd_metadata.document(p_application_id));
        pages := d.get_array('pages');
        for i in 0 .. pages.get_size-1 loop
            node := treat(pages.get(i) as json_object_t);
            if node.get_number('pageId') = p_page_id then
                result := to_clob('<section class="afd-summary"><span class="afd-eyebrow">APPLICATION ' || p_application_id || ' / PAGE ' || p_page_id || '</span><h1>' || apex_escape.html(node.get_string('name')) || '</h1><p>' || apex_escape.html(nvl(node.get_string('comment'),'No developer comment recorded for this page.')) || '</p><div class="afd-tags"><span class="afd-badge">' || apex_escape.html(case when p_page_id=0 then 'Global page' else node.get_string('mode') end) || '</span><span class="afd-badge">' || apex_escape.html(nvl(node.get_string('authorization'),'No page authorization scheme declared')) || '</span></div></section>');
                return result;
            end if;
        end loop;
        raise_application_error(-20003,'Page is not available.');
    end;
    function component_detail(p_application_id number,p_page_id number,p_key varchar2) return clob is
        n json_object_t := json_object_t.parse(afd_metadata.component(p_application_id,p_page_id,p_key));
        props json_object_t;
        sources json_array_t;
        src json_object_t;
        keys json_key_list;
        value_obj json_element_t;
        value_text clob;
        result clob;
        skip_source boolean;
    begin
        dbms_lob.createtemporary(result,true);
        dbms_lob.append(result,to_clob('<article class="afd-component"><span class="afd-eyebrow">' || apex_escape.html(n.get_string('family')) || '</span><h1>' || apex_escape.html(n.get_string('name')) || '</h1><p>' || apex_escape.html(nvl(n.get_string('comment'),'No developer comment recorded.')) || '</p><div class="afd-tags"><span class="afd-badge">' || apex_escape.html(n.get_string('sourceKind')) || '</span><span class="afd-badge">' || apex_escape.html(n.get_string('key')) || '</span></div><p class="afd-note">This is the declared definition. It does not establish which path ran or explain the internals of called packages.</p>'));
        block_code(result,'Provenance',n.get_object('origin').to_clob);
        block_code(result,'Declared references',n.get_array('references').to_clob);
        sources := n.get_array('sources');
        for s in 0 .. sources.get_size-1 loop
            src := treat(sources.get(s) as json_object_t);
            block_code(result,src.get_string('column') || ' · ' || src.get_string('language'),src.get_clob('text'),true);
        end loop;
        props := n.get_object('properties');
        keys := props.get_keys;
        dbms_lob.append(result,to_clob('<h2>Definition</h2>'));
        for k in 1 .. keys.count loop
            skip_source := false;
            for s in 0 .. sources.get_size-1 loop
                src := treat(sources.get(s) as json_object_t);
                if keys(k)=src.get_string('column') then skip_source := true; end if;
            end loop;
            value_obj := props.get(keys(k));
            if not value_obj.is_null and not skip_source then
                if value_obj.is_string then value_text := props.get_clob(keys(k)); else value_text := value_obj.to_clob; end if;
                block_code(result,keys(k),value_text,keys(k)='ATTRIBUTES');
            end if;
        end loop;
        dbms_lob.append(result,to_clob('</article>'));
        return result;
    end;
    procedure download_markdown(p_application_id number) is
        text_data clob;
        file_data blob;
        dest_offset integer := 1;
        src_offset integer := 1;
        context_value integer := 0;
        warning_value integer;
    begin
        afd_metadata.assert_access(p_application_id);
        text_data := afd_markdown.render_document(afd_metadata.document(p_application_id));
        dbms_lob.createtemporary(file_data,true);
        dbms_lob.converttoblob(file_data,text_data,dbms_lob.lobmaxsize,dest_offset,src_offset,nls_charset_id('AL32UTF8'),context_value,warning_value);
        if warning_value != 0 then raise_application_error(-20007,'UTF-8 conversion failed.'); end if;
        apex_http.download(
            p_blob => file_data,
            p_content_type => 'text/markdown; charset=UTF-8',
            p_filename => 'application-' || to_char(p_application_id,'FM99999999999999999990') || '.md',
            p_is_inline => false);

    end;
end afd_ui;
/
