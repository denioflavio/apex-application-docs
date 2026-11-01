# Installation and operation

Install the supporting objects in the application's parsing schema, then validate/import the APEXLang app. Change the deployment JSON to your workspace/schema/unused application ID. This project does not require broad DBA grants or writes to APEX product tables.

## Owner configuration

`AFD_ALLOWED_USERS` contains uppercase APEX account usernames. The default initial owner is ADMIN. Add your existing account with `database/grant-owner.sql` or a bind-based INSERT from your database client, then remove unwanted allowlist entries and commit. Authentication uses APEX Accounts; adding an allowlist row does not create a user or password.

Every owner of this installation can inspect the applications visible in its current workspace. This is not per-application delegated access. Install separately or extend the authorization model if you require different application permissions per user.

## Smoke checks

- Sign in as an allowed user; confirm applications belong to the installation workspace.
- Open an application, a page and a component drawer. Inspect a textual source and an Invoke API process with declarative JSON attributes.
- Export Markdown; check the index, global page, authorization section, comments and full source.
- Confirm an anonymous browser and an authenticated nonowner cannot read metadata or download it.
- Try a nonexistent application, a page belonging to another app, and a component key from another page: no source should be returned.
- At desktop and mobile widths, check native search, scrolling, keyboard focus, close drawer and Copy fallback.

## Automated SQL tests

`database/tests/test_documentation.sql` is the integration suite used against the author's existing app 106. It does not modify that app; it creates a large renderer fixture in memory. It assumes a valid APEX session, owner ADMIN, and app 106 with its standard login Invoke API processes. It is an author verification fixture, not a universal install smoke script; adapt the reference app/account for your own workspace.

## Updating

Back up the existing app and packages before an update. Re-run package installation and review the allowlist. Validate APEXLang and import in the checked authenticated session after explicit operator approval. No generated APEX SQL should be edited.

## Removing

Remove the APEX app through your normal APEX administration workflow. After confirming no application depends on the packages, run the explicit `database/uninstall.sql` separately. It removes only AFD objects and the owner allowlist; it does not remove any documented application or business data.
