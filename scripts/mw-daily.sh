#!/bin/sh
set -u
# shellcheck source=/dev/null
. /scripts/_maintenance.sh

run initSiteStats             initSiteStats.php --update
run rebuildData               SemanticMediaWiki:rebuildData --shallow-update
run disposeOutdatedEntities   SemanticMediaWiki:disposeOutdatedEntities
run rebuildPropertyStatistics SemanticMediaWiki:rebuildPropertyStatistics
run rebuildConceptCache       SemanticMediaWiki:rebuildConceptCache --update --create

# Last on purpose: this is the known-broken step (it burns ~607s before
# throwing), so if the deadline trips or an operator aborts, the cut lands here
# rather than on working SMW maintenance. Order is otherwise irrelevant -- no
# step consumes another's output.
run UpdateSuggesterIndex      CirrusSearch:UpdateSuggesterIndex

finish
