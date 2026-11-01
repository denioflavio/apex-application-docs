set define on
-- SQLcl prompts for an existing APEX workspace account. No passwords are stored.
accept afd_username char prompt 'Existing APEX workspace username: '
merge into afd_allowed_users d using (select upper('&afd_username') username from dual) s
on (d.username = s.username)
when not matched then insert (username) values (s.username);
commit;
undefine afd_username

set define off
