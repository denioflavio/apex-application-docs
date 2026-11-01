# Compatibility and verification

- Oracle Database 23.26.4.1.0, AL32UTF8.
- Runtime inspected: Oracle APEX 26.1.6.
- SQLcl used for compiler validation: 26.1.2.
- Official documentation consulted: APEX 26.2. No claim of live 26.2 testing.
- Strict structural formatting: passed.
- Compiler-truth audit: passed against the SQLcl 26.1 compiler metadata (26.1.0+3102).
- Live `apex validate`: passed.
- SQL integration/renderer suite: 34 checks passed.
- APEX import: successful after the explicit post-check choice, following a fresh live validation in the same SQLcl session. Browser checks passed for application/page navigation, source drawer, Copy and Escape close, native attachment download native page/component filtering and filter removal with retained AJAX context, and the 375 px iPhone SE profile.

## Tooling discrepancy

The installed APEXLang skill's local heuristic lint reports `REPORT_REGION_LINK_BLOCK_UNSUPPORTED_001` for native IR custom row links. The live 26.1 compiler accepts this shape. Its suggested column-level plainText/link shape is rejected by that same compiler; link-type columns compile but are also forbidden by the heuristic. This is a tooling compatibility defect, not a reason to substitute handcrafted URLs or edit generated SQL. Raw diagnostics remain in author verification material. The authoritative compilation and compiler-truth audit pass; the heuristic lint is not reported as passing.

The scaffold's duplicate `page:` / page-item `name:` properties and root `alias:` property were also rejected by the live 26.1 compiler and removed. Comment fences use no language annotation because comments are text. Standard-page regions use `body`; the drawer uses `contentBody`.

## Source extraction boundaries

Only public views and selected documented metadata fields are used. Static IDs are preserved when exposed. Processes with empty PROCESS_SOURCE can carry their behavior in ATTRIBUTES; this was verified using native Invoke API login processes. Plugin-specific attributes are retained but not semantically interpreted for all plugins.

The integration suite contains 24 renderer/security checks and 10 count/key checks. The browser download was saved as application-108.md and verified as complete UTF-8. Page10 uses a full POST; APEX_HTTP.DOWNLOAD clears the output buffer and supplies the attachment response.

## Portability check

The public deployment file contains workspace/schema placeholders, and public sources were checked for author paths and connection settings. Strict formatting and compiler-truth also passed on the exported public tree. A clean installation in a second independent workspace has not been executed. The SQL tests include author-specific fixture IDs; adapt them before running elsewhere.
