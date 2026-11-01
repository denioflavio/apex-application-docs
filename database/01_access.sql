-- Run as the installation parsing schema. Re-running preserves existing owners.
begin
    execute immediate 'create table afd_allowed_users (username varchar2(255 char) primary key)';
exception
    when others then
        if sqlcode != -955 then raise; end if;
end;
/
-- Initial OCI owner; change with the documented grant-owner.sql script.
merge into afd_allowed_users d using (select 'ADMIN' username from dual) s
on (d.username = s.username)
when not matched then insert (username) values (s.username);
commit;
