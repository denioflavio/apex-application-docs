set serveroutput on
set define off
-- Requires a valid APEX session, e.g. create_session for an existing demo app.
declare
    d json_object_t;
    components json_array_t;
    pages json_array_t;
    app_obj json_object_t;
    n json_object_t;
    props json_object_t;
    sources json_array_t;
    src json_object_t;
    refs json_array_t;
    fixture json_object_t;
    large_text clob;
    json_data clob;
    md clob;
    md2 clob;
    saved_user varchar2(255) := apex_application.g_user;
    total number := 0;
    expected_count number;
    actual_count number;
    found_declarative boolean := false;
    procedure assert_true(p_condition boolean,p_message varchar2) is
    begin
        if p_condition is null or not p_condition then raise_application_error(-20100,p_message); end if;
        total := total + 1;
        dbms_output.put_line('PASS ' || p_message);
    end;
begin
    d := json_object_t.parse(afd_metadata.document(106));
    assert_true(d.get_string('schemaVersion')='1.0','normalized model version');
    assert_true(d.get_object('scope').get_number('applicationId')=106,'application scope');
    pages := d.get_array('pages');
    select count(*) into expected_count from apex_application_pages where application_id=106;
    assert_true(pages.get_size=expected_count,'page count matches public view');
    components := d.get_array('components');
    select count(*) into expected_count from apex_application_page_proc where application_id=106;
    actual_count := 0;
    for i in 0 .. components.get_size-1 loop
        n := treat(components.get(i) as json_object_t);
        if n.get_string('family')='process' then
            actual_count := actual_count+1;
            props := n.get_object('properties');
            if props.get_string('PROCESS_TYPE_PLUGIN_STATIC_ID')='NATIVE_INVOKE_API' then
                assert_true(n.get_string('sourceKind')='declarative','Invoke API preserved as declarative');
                assert_true(props.get('ATTRIBUTES').is_object,'JSON attributes remain structured');
                found_declarative := true;
            end if;
        end if;
    end loop;
    assert_true(found_declarative,'declarative process fixture found');
    assert_true(actual_count=expected_count,'process count matches public view');
    md := afd_markdown.render_document(d.to_clob);
    assert_true(dbms_lob.instr(md,'Shared authorizations')>0,'shared authorization section');
    assert_true(dbms_lob.instr(md,'APEX_APPLICATION_PAGE_PROC')>0,'provenance retained');
    md2 := afd_markdown.render_document(d.to_clob);
    assert_true(dbms_lob.compare(md,md2)=0,'same captured model produces identical Markdown');
    -- Negative paths must fail before returning any source.
    apex_application.g_user := 'NOBODY';
    begin
        json_data := afd_metadata.document(106);
        raise_application_error(-20101,'Anonymous access unexpectedly succeeded');
    exception when others then assert_true(sqlcode=-20001,'anonymous metadata rejected'); end;
    begin
        afd_ui.download_markdown(106);
        raise_application_error(-20101,'Anonymous download unexpectedly succeeded');
    exception when others then assert_true(sqlcode=-20001,'anonymous download rejected'); end;
    apex_application.g_user := 'AFD_UNAUTHORIZED_TEST';
    begin
        json_data := afd_metadata.document(106);
        raise_application_error(-20101,'Nonowner access unexpectedly succeeded');
    exception when others then assert_true(sqlcode=-20001,'nonowner rejected'); end;
    apex_application.g_user := saved_user;
    begin
        json_data := afd_metadata.document(-1);
        raise_application_error(-20101,'Invalid app unexpectedly succeeded');
    exception when others then assert_true(sqlcode=-20002,'unavailable application rejected'); end;
    begin
        json_data := afd_metadata.component(106,1,'process:wrong');
        raise_application_error(-20101,'Invalid component unexpectedly succeeded');
    exception when others then assert_true(sqlcode=-20004,'component membership enforced'); end;
    begin
        json_data := afd_metadata.component(106,-1,'process:wrong');
        raise_application_error(-20101,'Invalid page unexpectedly succeeded');
    exception when others then assert_true(sqlcode=-20003,'page membership enforced'); end;
    -- Pure renderer fixture: never insert into or modify an APEX application.
    fixture := json_object_t.parse('{"schemaVersion":"1.0","collectorVersion":"test","apexVersion":"test","capturedAtUtc":"2026-10-31T00:00:00Z","application":{"APPLICATION_NAME":"Ação <script>alert(1)</script>"},"pages":[{"pageId":1,"name":"Página de aprovação"},{"pageId":2,"name":"Empty"}],"components":[],"coverage":["process"],"limitations":"Fixture only"}');
    dbms_lob.createtemporary(large_text,true);
    for i in 1..20 loop dbms_lob.append(large_text,to_clob(rpad('ação ',4000,'x'))); end loop;
    dbms_lob.append(large_text,to_clob(chr(10)||'``` embedded fence'||chr(10)||'```` longer fence'||chr(10)||'<script>not executable</script>'||chr(10)||'raise_application_error(-20999,''SOURCE MUST NEVER EXECUTE'');'||chr(10)||'END-OF-LARGE-SOURCE'));
    n := json_object_t.parse('{"key":"process:1","family":"process","name":"Render fixture","pageId":1,"sourceKind":"textual","properties":{"PROCESS_POINT":"AFTER_SUBMIT"},"origin":{"view":"fixture"},"references":[],"sources":[]}');
    sources := json_array_t();
    src := json_object_t();
    src.put('column','PROCESS_SOURCE'); src.put('language','plsql'); src.put('text',large_text);
    sources.append(src); n.put('sources',sources);
    components := json_array_t(); components.append(n); fixture.put('components',components);
    md := afd_markdown.render_document(fixture.to_clob);
    assert_true(dbms_lob.getlength(md)>80000,'source over 32 KB preserved');
    declare
        text_start pls_integer := dbms_lob.instr(md,'`````plsql') + length('`````plsql') + 1;
    begin
        assert_true(dbms_lob.compare(md,large_text,dbms_lob.getlength(large_text),text_start,1)=0,'full source exactly preserved');
    end;
    assert_true(dbms_lob.instr(md,'`````plsql')>0,'fence longer than embedded backticks');
    assert_true(dbms_lob.instr(md,'Ação &lt;script&gt;')>0,'heading HTML escaped and Unicode preserved');
    assert_true(dbms_lob.instr(md,'No components in the supported families')>0,'empty page explicit');
    dbms_output.put_line('ALL ' || total || ' CHECKS PASSED');
exception when others then
    apex_application.g_user := saved_user;
    raise;
end;
/
