#!/bin/sh
set -u
# shellcheck source=/dev/null
. /scripts/_maintenance.sh

for page in Ancientpages Deadendpages Fewestrevisions Mostlinked Mostrevisions Wantedpages; do
  run "updateSpecialPages $page" updateSpecialPages --override --only="$page"
done

run initSiteStats initSiteStats --update --active

finish
