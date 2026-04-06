#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Fetch latest tags from Docker Hub (most recently updated)
echo "Fetching latest tags from Docker Hub..."

MW_TAG=$(curl -sf "https://hub.docker.com/v2/repositories/starcitizentools/mediawiki/tags/?page_size=20&ordering=last_updated" \
  | python3 -c "
import sys, json, re
data = json.load(sys.stdin)
for r in data['results']:
    if re.match(r'^smw-\d', r['name']):
        print(r['name'])
        break
")

if [ -z "$MW_TAG" ]; then
  echo "Error: Failed to fetch mediawiki tag from Docker Hub" >&2
  exit 1
fi

NGINX_TAG=$(curl -sf "https://hub.docker.com/v2/repositories/starcitizentools/nginx/tags/?page_size=20&ordering=last_updated" \
  | python3 -c "
import sys, json, re
data = json.load(sys.stdin)
for r in data['results']:
    if re.match(r'^\d', r['name']):
        print(r['name'])
        break
")

if [ -z "$NGINX_TAG" ]; then
  echo "Error: Failed to fetch nginx tag from Docker Hub" >&2
  exit 1
fi

# Derive jobrunner tag: extract version suffix from mediawiki tag (e.g., smw-26.04.06.498 → 26.04.06.498)
MW_VERSION="${MW_TAG#smw-}"
JOBRUNNER_TAG="smw-jobrunner-${MW_VERSION}"

echo ""
echo "Latest tags:"
echo "  mediawiki:  ${MW_TAG}"
echo "  jobrunner:  ${JOBRUNNER_TAG}"
echo "  nginx:      ${NGINX_TAG}"
echo ""

# Update mediawiki smw-* (exclude smw-jobrunner-* by matching smw- followed by a digit)
sed -i '' -E "s|starcitizentools/mediawiki:smw-[0-9][^\"]*|starcitizentools/mediawiki:${MW_TAG}|g" \
  "$SCRIPT_DIR/mediawiki/php-mediawiki.yaml" \
  "$SCRIPT_DIR/mediawiki/mw-cronjob.yaml" \
  "$SCRIPT_DIR/shared/backup-cronjob.yaml"

# Update mediawiki smw-jobrunner-*
sed -i '' -E "s|starcitizentools/mediawiki:smw-jobrunner-[0-9][^\"]*|starcitizentools/mediawiki:${JOBRUNNER_TAG}|g" \
  "$SCRIPT_DIR/mediawiki/php-mediawiki-jobs.yaml"

# Update nginx
sed -i '' -E "s|starcitizentools/nginx:[0-9][^\"]*|starcitizentools/nginx:${NGINX_TAG}|g" \
  "$SCRIPT_DIR/mediawiki/nginx.yaml"

echo "Done. Updated manifests."
