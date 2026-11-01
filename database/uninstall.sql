-- Explicitly destructive: run only after removing the catalog app and checking dependencies.
-- Does not modify any application inspected by the catalog.
drop package afd_ui;
drop package afd_markdown;
drop package afd_metadata;
drop table afd_allowed_users;
