#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Our app images live in GHCR as PRIVATE packages, so listing tags needs an
# authenticated GitHub token with the read:packages scope. We reuse the gh CLI
# for auth (it handles tokens + pagination). The GitHub Packages API returns
# versions newest-first by created_at, so the first tag matching our pattern is
# the most recently pushed -- same behaviour as the old Docker Hub query.
GHCR_ORG="starcitizentools"

# Preflight: gh present and scoped for package reads.
if ! command -v gh >/dev/null 2>&1; then
  echo "Error: gh (GitHub CLI) is required but not installed." >&2
  exit 1
fi
if ! gh auth status 2>/dev/null | grep -q "read:packages"; then
  echo "Error: gh token is missing the 'read:packages' scope." >&2
  echo "       Run: gh auth refresh -h github.com -s read:packages" >&2
  exit 1
fi

# latest_tag <package> <regex> -> newest tag matching the regex (or empty).
latest_tag() {
  local package="$1" regex="$2"
  gh api --paginate "/orgs/${GHCR_ORG}/packages/container/${package}/versions" \
    --jq '.[].metadata.container.tags[]' \
    | grep -E "$regex" \
    | head -1
}

echo "Fetching latest tags from GHCR..."

# mediawiki: smw-<version>, excluding smw-latest and smw-jobrunner-* (both share
# this package). Anchoring smw- to a digit drops both.
MW_TAG=$(latest_tag mediawiki '^smw-[0-9]')
if [ -z "$MW_TAG" ]; then
  echo "Error: Failed to fetch mediawiki tag from GHCR" >&2
  exit 1
fi

# nginx: bare <version> tag (e.g. 26.06.03.562), excluding 'latest'.
NGINX_TAG=$(latest_tag nginx '^[0-9]')
if [ -z "$NGINX_TAG" ]; then
  echo "Error: Failed to fetch nginx tag from GHCR" >&2
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

# Detect sed in-place flag (BSD sed needs '' suffix; GNU sed does not)
if sed --version >/dev/null 2>&1; then
  SED_INPLACE=(sed -i -E)
else
  SED_INPLACE=(sed -i '' -E)
fi

# Update mediawiki smw-* (exclude smw-jobrunner-* by matching smw- followed by a digit)
"${SED_INPLACE[@]}" "s|starcitizentools/mediawiki:smw-[0-9][^\"]*|starcitizentools/mediawiki:${MW_TAG}|g" \
  "$SCRIPT_DIR/mediawiki/php-mediawiki.yaml" \
  "$SCRIPT_DIR/mediawiki/mw-cronjob.yaml" \
  "$SCRIPT_DIR/shared/backup-cronjob.yaml"

# Update mediawiki smw-jobrunner-*
"${SED_INPLACE[@]}" "s|starcitizentools/mediawiki:smw-jobrunner-[0-9][^\"]*|starcitizentools/mediawiki:${JOBRUNNER_TAG}|g" \
  "$SCRIPT_DIR/mediawiki/php-mediawiki-jobs.yaml"

# Update nginx
"${SED_INPLACE[@]}" "s|starcitizentools/nginx:[0-9][^\"]*|starcitizentools/nginx:${NGINX_TAG}|g" \
  "$SCRIPT_DIR/mediawiki/nginx.yaml"

echo "Done. Updated manifests."
