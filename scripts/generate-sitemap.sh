#!/bin/sh
set -e
DUMP=/tmp/dump
IDX="$DUMP/sitemap-index-starcitizentools.xml"

# restartPolicy: OnFailure reuses the same emptyDir, so a failed attempt's
# shards survive into the retry and would publish as orphans.
rm -f "$DUMP"/sitemap-*.xml

# 256M is ~4.5x the measured worst case and half the 512Mi cgroup limit.
# Do NOT drop this flag: MaintenanceRunner then sets memory_limit to -1, which
# trades a logged PHP fatal for a silent cgroup OOMKill.
php /var/www/mediawiki/maintenance/run.php generateSitemap \
  --memory-limit=256M \
  --fspath="$DUMP/" \
  --identifier=starcitizentools \
  --server=https://starcitizen.tools \
  --compress=no \
  --skip-redirects

# The index must point at the bucket host, the shards at the wiki -- but both
# are built from $wgServer, so --server moves them together and cannot split
# them. Anchored on the scheme to stay idempotent across an OnFailure retry.
sed -i 's|https://starcitizen\.tools/|https://sitemap.starcitizen.tools/|g' "$IDX"

grep -q '</sitemapindex>' "$IDX" || { echo "FATAL: index has no closing </sitemapindex> - generator died mid-run, refusing to publish"; exit 1; }
grep -q '<loc>https://sitemap\.starcitizen\.tools/' "$IDX" || { echo "FATAL: index has no <sitemap> entries - refusing to publish"; exit 1; }
n=0
for f in "$DUMP"/sitemap-starcitizentools-*.xml; do
  [ -s "$f" ] || { echo "FATAL: sitemap shard missing or empty: $f - refusing to publish"; exit 1; }
  grep -q '</urlset>' "$f" || { echo "FATAL: sitemap shard truncated (no </urlset>): $f - refusing to publish"; exit 1; }
  # A well-formed but empty <urlset> passes every structural check above.
  # SitemapGenerator emits exactly that if $wgSitemapNamespaces resolves to [].
  grep -q '<url>' "$f" || { echo "FATAL: shard has ZERO urls: $f - refusing to publish"; exit 1; }
  n=$((n + 1))
done
# || true is load-bearing: grep -c exits 1 on a zero count, which under set -e
# would abort with no message at all.
total=$(cat "$DUMP"/sitemap-starcitizentools-*.xml | grep -c '<url>' || true)
[ "$total" -ge 20000 ] || { echo "FATAL: only $total URLs (expected ~42000) - refusing to publish"; exit 1; }
echo "sitemap OK: $n shard(s), $total urls, index $(wc -c < "$IDX") bytes"

# Shards first: a single "$DUMP"/* glob would upload the index ahead of the
# shards it references ('sitemap-index-' sorts first).
s3cmd put --access_key="${SITEMAP_ACCESS_KEY}" --secret_key="${SITEMAP_SECRET_KEY}" -f --config=/www-data/.s3cfg "$DUMP"/sitemap-starcitizentools-*.xml s3://sitemap.starcitizen.tools
s3cmd put --access_key="${SITEMAP_ACCESS_KEY}" --secret_key="${SITEMAP_SECRET_KEY}" -f --config=/www-data/.s3cfg "$IDX" s3://sitemap.starcitizen.tools

# ONE-SHOT (2026-09): delete the sitemap shards orphaned by MW 1.45's filename
# change (sitemap-<id>-NS_<ns>-<n>.xml -> sitemap-<id>-<n>.xml). They still
# return HTTP 200, so search engines that discovered them through the old index
# keep re-crawling frozen data -- the 2024 set even advertises Talk:, User: and
# Module: pages that the current sitemap deliberately excludes. s3cmd put never
# deletes, so nothing else will ever remove them.
#
# Safe: the current shard is a superset of the 2026-08-29 set (verified by URL
# set comparison -- the only difference was one page rename), and removing a
# sitemap never deindexes anything.
#
# Exact keys only. NOT `del --recursive` or `sync --delete-removed`: both need
# ListBucket, which this key may not have, and a sync deletes by diff against
# /tmp/dump -- one bad run from emptying the bucket. A key that is already gone
# is a harmless no-op.
#
# REMOVE THIS BLOCK once it has run successfully once.
for ns in 0 1 2 3 4 5 6 8 10 11 12 14 15 102 112 828 1199 \
          3000 3002 3004 3006 3008 3016 30000; do
  s3cmd del --access_key="${SITEMAP_ACCESS_KEY}" --secret_key="${SITEMAP_SECRET_KEY}" \
    --config=/www-data/.s3cfg \
    "s3://sitemap.starcitizen.tools/sitemap-starcitizentools-NS_${ns}-0.xml" || true
done
