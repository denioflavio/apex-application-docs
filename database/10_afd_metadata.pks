create or replace package afd_metadata authid definer as
    c_version constant varchar2(20) := '1.0.0';
    type catalog_row is record (
        application_id number, page_id number, component_key varchar2(200),
        name varchar2(4000), family varchar2(50), type_name varchar2(4000),
        description varchar2(4000), sort_order number, component_count number
    );
    type catalog_rows is table of catalog_row;
    function is_allowed return boolean;
    procedure assert_access(p_application_id number default null, p_page_id number default null);
    function document(p_application_id number) return clob;
    function component(p_application_id number, p_page_id number, p_key varchar2) return clob;
    function application_list return catalog_rows pipelined;
    function page_list(p_application_id number) return catalog_rows pipelined;
    function component_list(p_application_id number, p_page_id number) return catalog_rows pipelined;
end afd_metadata;
/
