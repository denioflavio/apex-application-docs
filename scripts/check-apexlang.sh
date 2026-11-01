#!/usr/bin/env bash
set -euo pipefail
app_path="${1:-application/apex-application-docs}"
: "${APEXCTL:?Set APEXCTL to the installed apexctl.mjs path}"
: "${AFD_COMPILER_HOME:?Set AFD_COMPILER_HOME to your SQLcl home matching the target compiler}"
node "$APEXCTL" apexlang format --app-path "$app_path" --strict-structure
node "$APEXCTL" apexlang compiler-truth audit --app-path "$app_path" --compiler-oracle-home "$AFD_COMPILER_HOME" --verify-component-attributes
printf '%s\n' 'Next: run apex validate in your target authenticated SQLcl session. See README.'
