#!/bin/sh
set -u
# shellcheck source=/dev/null
. /scripts/_maintenance.sh

run initSiteStats             initSiteStats.php --update
run UpdateSuggesterIndex      CirrusSearch:UpdateSuggesterIndex
run rebuildData               SemanticMediaWiki:rebuildData --shallow-update
run disposeOutdatedEntities   SemanticMediaWiki:disposeOutdatedEntities
run rebuildPropertyStatistics SemanticMediaWiki:rebuildPropertyStatistics
run rebuildConceptCache       SemanticMediaWiki:rebuildConceptCache --update --create

finish
