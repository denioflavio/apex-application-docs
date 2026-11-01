set serveroutput on
set define off
declare
    l_doc clob := afd_metadata.document(108);
    l_expected number;
    l_actual number;
    l_bad number;
    l_families apex_t_varchar2 := apex_t_varchar2('region','item','button','validation','process','branch','dynamicAction','dynamicActionAction','authorization');
    l_views apex_t_varchar2 := apex_t_varchar2('APEX_APPLICATION_PAGE_REGIONS','APEX_APPLICATION_PAGE_ITEMS','APEX_APPLICATION_PAGE_BUTTONS','APEX_APPLICATION_PAGE_VAL','APEX_APPLICATION_PAGE_PROC','APEX_APPLICATION_PAGE_BRANCHES','APEX_APPLICATION_PAGE_DA','APEX_APPLICATION_PAGE_DA_ACTS','APEX_APPLICATION_AUTHORIZATION');
begin
    for i in 1..l_families.count loop
        execute immediate 'select count(*) from '||l_views(i)||' where application_id=:id' into l_expected using 108;
        select count(*) into l_actual from json_table(l_doc,'$.components[*]' columns(family varchar2(50) path '$.family')) where family=l_families(i);
        if l_expected != l_actual then raise_application_error(-20102,l_families(i)||': count mismatch'); end if;
        dbms_output.put_line('PASS '||l_families(i)||': '||l_actual||' matches public view');
    end loop;
    select count(*) into l_bad from json_table(l_doc,'$.components[*]' columns(component_key varchar2(200) path '$.key')) where instr(component_key,':')>0;
    if l_bad>0 then raise_application_error(-20103,'Component key contains URL delimiter'); end if;
    dbms_output.put_line('PASS component keys avoid APEX URL delimiters');
    dbms_output.put_line('ALL 10 COUNT/KEY CHECKS PASSED');
end;
/
