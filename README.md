# APEX Application Docs

Browse the declared definition of an Oracle APEX application and export it as a Markdown document. No AI service, API key or external runtime dependency is required.

The catalog reads public APEX views. It keeps page/component identity, developer comments, declared conditions, authorization references, source text and declarative attributes together. It never executes the source code it documents.

## What you get

- Native searchable reports for applications, pages and components.
- A read-only component drawer with provenance, references, source and declarative configuration.
- One UTF-8 Markdown document per application, including shared authorization definitions.
- A versioned internal JSON model that can later support contextual code explanations.

## Requirements

Oracle Database with the installed APEX runtime, an APEX workspace/parsing schema, SQLcl with `apex validate` and `apex import`, and permission to create the supporting table/packages in that schema.

The supporting packages were compiled and exercised on APEX **26.1.6**, Oracle Database **23.26.4.1.0**, with SQLcl **26.1.2**. Documentation was consulted for **APEX 26.2**; a 26.2 runtime has **not** been tested. Check your version's dictionary columns against [docs/metadata-map.json](docs/metadata-map.json) before installing on another release.

## Install

1. Clone this repository and connect SQLcl as your intended parsing schema. Do not run the catalog as an administrative database account.
2. Run `@database/install.sql`. The script creates `AFD_ALLOWED_USERS`, `AFD_METADATA`, `AFD_MARKDOWN` and `AFD_UI`; it fails if any package has compilation errors. Re-running preserves configured owners.
3. The initial APEX account allowed by the installation script is `ADMIN`. Use `@database/grant-owner.sql` to add your existing workspace account. Remove the `ADMIN` row if that account should not use your installation. No account or password is created by this project.
4. Edit `application/apex-application-docs/deployments/default.json`: set your workspace name, an unused application ID, and the parsing schema used in step 2.
5. Validate, review, then import the APEXLang source in the same authenticated SQLcl session:

```sql
apex validate -input application/apex-application-docs -workspace YOUR_WORKSPACE
-- Continue only after reviewing a successful check:
apex import -input application/apex-application-docs -workspace YOUR_WORKSPACE
```

6. Run the new application and sign in with an allowed **APEX workspace account**. Select an application, open a page and inspect a component. On the application screen, choose **Export Markdown**.

See [docs/installation.md](docs/installation.md) for removal, access configuration and smoke checks. This is an installable developer tool; no hosted public demo or credentials are provided.

## Architecture

`AFD_METADATA` is the only collector. It creates the normalized model used by page/component reports, custom UI surfaces and `AFD_MARKDOWN`. `AFD_UI` supplies escaped hero/detail rendering and an authorized UTF-8 download adapter. CSS and presentation-only JavaScript are static APEX application files.

See [docs/model.md](docs/model.md), [docs/architecture.md](docs/architecture.md) and [docs/compatibility.md](docs/compatibility.md).

## Limits

This version documents regions, items, buttons, validations, processes, branches, dynamic actions/actions and application authorization schemes. It includes global and utility pages. It does not document every shared-component family, expand called package bodies, evaluate authorizations, or establish which code ran. Explicit references are configuration references, not a complete dependency graph.

No metadata snapshots, generated explanations or model credentials are stored. Application/component IDs are installation-local. Exports reflect a collection time; they are not a historical deployment audit. A document may contain application source and internal configuration, so distribute exports with the same care as application source.

## Validation status

Strict structure formatting, compiler-truth audit and live APEXLang compilation passed on APEX 26.1.6. The database suite passed 23 checks, covering direct-view counts, declarative Invoke API processes, authorization and membership failures, deterministic Markdown, Unicode, HTML-like labels, embedded backticks, empty pages and an 80 KB source fixture.

Installation of the APEX app and browser acceptance are recorded separately in [docs/compatibility.md](docs/compatibility.md). A successful compile is not a browser acceptance result.

## Series

Part 1: metadata catalog and Markdown export. Part 2: contextual explanations connected to their source, review and change tracking. The first version remains fully useful without AI.

MIT License.
