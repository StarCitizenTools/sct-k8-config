#!/bin/sh
set -u
# shellcheck source=/dev/null
. /scripts/_maintenance.sh

run initSiteStats             initSiteStats.php --update
prepare_exception_log /tmp/smw-rebuild
# Still `run`, not run_soft: SMW exits non-zero only when it actually logged an
# exception, so a red Job here means real data to fix, not a flaky step.
run rebuildData               SemanticMediaWiki:rebuildData --shallow-update \
                              --ignore-exceptions --exception-log /tmp/smw-rebuild
dump_exception_log /tmp/smw-rebuild
run disposeOutdatedEntities   SemanticMediaWiki:disposeOutdatedEntities
run rebuildPropertyStatistics SemanticMediaWiki:rebuildPropertyStatistics
run rebuildConceptCache       SemanticMediaWiki:rebuildConceptCache --update --create

# Last on purpose: this is the known-broken step (it burns ~607s before
# throwing), so if the deadline trips or an operator aborts, the cut lands here
# rather than on working SMW maintenance. Order is otherwise irrelevant -- no
# step consumes another's output.
run UpdateSuggesterIndex      CirrusSearch:UpdateSuggesterIndex

finish
