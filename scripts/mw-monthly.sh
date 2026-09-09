#!/bin/sh
set -u
# shellcheck source=/dev/null
. /scripts/_maintenance.sh

run cleanupUploadStash        cleanupUploadStash
run cleanupWatchlist          cleanupWatchlist --fix
run refreshLinks              refreshLinks --dfn-only
run removeDuplicateEntities   SemanticMediaWiki:removeDuplicateEntities

finish
