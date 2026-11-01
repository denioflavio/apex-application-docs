# Internal documentation model — schemaVersion 1.0

`AFD_METADATA.DOCUMENT` returns a JSON CLOB, not a public REST endpoint. The app, Markdown renderer and future context assembler consume this model.

- `schemaVersion`, `collectorVersion`, `apexVersion`, `capturedAtUtc`: contract/provenance information.
- `scope`: workspace ID/name and application ID.
- `application`: selected public-view properties, including comments and declared authorization.
- `pages`: numeric pageId, name, mode/function/group, comments, authorization and origin.
- `components`: objects in a fixed family order and page/sequence/ID order.
- `coverage`, `limitations`: explicit boundaries of extraction.

Each component contains `key` (`family-installation-local-id`), `id`, `family`, `name`, optional `pageId`, optional `staticId`/`sequence`, `comment`, `origin` (view/idColumn), `properties`, `sources` and `references`.

`sourceKind` is `textual` when configured textual source columns are populated; otherwise `declarative` for families defined without a textual source column or when JSON attributes are present, or `notProvided`. It describes the extracted representation, not whether a component can execute behavior. JSON attributes can themselves contain code; they remain available in the declarative properties. Empty textual source never means "this component does nothing".

Sources preserve source column, language where known and complete text. Unknown languages remain `text`. SQL source is never executed to infer its result. References retain exact property/value and `kind: declared`; unresolved external references remain references.

The properties selected for each family are listed in metadata-map.json. Nulls are retained in JSON and omitted from detailed Markdown properties. The Markdown renderer is deterministic for one captured model. New collections have a different capture time and may include changed metadata.

IDs are not stable cross-environment identifiers. Static IDs are retained when the relevant view exposes them; names are descriptive, not guaranteed unique.
