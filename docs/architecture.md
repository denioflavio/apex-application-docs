# Architecture

Public APEX views → AFD_METADATA normalized document → native reports / escaped composed details / AFD_MARKDOWN.

## Collector

The public API is `AFD_METADATA.DOCUMENT(application_id) RETURN CLOB`. `APPLICATION_LIST`, `PAGE_LIST(application_id)` and `COMPONENT_LIST(application_id,page_id)` are SQL-queryable pipelined functions. `COMPONENT(application_id,page_id,key)` retrieves one member of the same document.

The private SQL projections are fixed in package source and recorded in metadata-map.json. Caller-supplied identifiers are bind values, never SQL fragments or view names. All queries are SELECTs over public views; the collector does not invoke documented conditions, source, authorization definitions or business packages.

`ASSERT_ACCESS` checks the owner allowlist and the current APEX session workspace via `SYS_CONTEXT('APEX$SESSION','WORKSPACE_ID')`. It verifies application/page membership; component detail verifies the component key belongs to that page. A database account able to execute arbitrary PL/SQL remains a trusted administrator of its own session and schema; this package does not create a separate database security boundary.

## Presentation

The application uses native Interactive Reports and native custom row links, a native modal drawer, APEX Accounts authentication and a package-based authorization scheme. Only hero, summaries and detailed code/property rendering use Dynamic Content. Every metadata value emitted into HTML is escaped in character-safe chunks. No metadata is interpolated into executable JavaScript.

The download process repeats the authorization/scope check, renders Markdown from the collected JSON, converts the full CLOB to an AL32UTF8 BLOB and downloads an attachment with a numeric application-based filename. Client context items are navigation inputs; they do not determine authorization.

## Cost and consistency

A document is collected on demand. There is no persisted cache or snapshot. A page render can collect more than once for summary and report. This deliberately simple v1 favors inspectability; profile collection on large applications before extending it. capturedAtUtc is collection time, not an assertion of atomic historical snapshot consistency.

## Next part

The model retains declared button/process/validation/branch references and source provenance. Part 2 can assemble a bounded action context, calculate a content fingerprint excluding capture timestamps, persist reviewed explanations, and mark them stale when the analyzed context changes. No AI endpoint or explanation persistence is shipped in v1.
