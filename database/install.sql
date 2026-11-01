whenever sqlerror exit sql.sqlcode rollback
set define off
@@01_access.sql
@@10_afd_metadata.pks
@@11_afd_metadata.pkb
@@20_afd_markdown.sql
@@30_afd_ui.sql
select object_name, object_type, status from all_objects
 where owner = sys_context('USERENV','CURRENT_SCHEMA') and object_name in ('AFD_METADATA','AFD_MARKDOWN','AFD_UI','AFD_ALLOWED_USERS')
 order by object_name, object_type;

begin
    for r in (select name, type, line, position, text from all_errors where owner = sys_context('USERENV','CURRENT_SCHEMA') and name in ('AFD_METADATA','AFD_MARKDOWN','AFD_UI')) loop
        raise_application_error(-20008,r.name || ':' || r.line || ' ' || r.text);
    end loop;
end;
/
