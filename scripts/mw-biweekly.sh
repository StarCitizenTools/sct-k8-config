#!/bin/sh
set -u
# shellcheck source=/dev/null
. /scripts/_maintenance.sh

for page in Ancientpages Deadendpages Fewestrevisions Mostlinked Mostrevisions Wantedpages; do
  run "updateSpecialPages $page" updateSpecialPages --override --only="$page"
done

run initSiteStats initSiteStats --update --active

# rebuildData here is incremental, not a full re-parse:
#  --revision-mode  only re-parses entities whose page revision changed.
#  --auto-recovery  checkpoints progress so an in-place container restart (an
#    eviction or OOM kill) resumes rather than starting over.
#  --skip-dispose   the daily job already runs disposeOutdatedEntities.
#  --ignore-exceptions  a bad Lua/parser page is logged and skipped, not fatal --
#    but SMW still exits non-zero when it logged any, so this is run_soft.
prepare_exception_log /tmp/smw-rebuild
run_soft rebuildData SemanticMediaWiki:rebuildData --revision-mode --auto-recovery \
  --skip-dispose --ignore-exceptions --exception-log /tmp/smw-rebuild --report-runtime

dump_exception_log /tmp/smw-rebuild

run setupStore SemanticMediaWiki:setupStore --skip-import

finish
