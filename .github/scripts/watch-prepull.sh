#!/usr/bin/env bash
# Wait for pre-pull Jobs, printing the kubelet's pull events as they happen so
# a multi-minute pull shows progress instead of silence.
#
# Usage: watch-prepull.sh TIMEOUT_SECONDS JOB=NODE [JOB=NODE ...]
#
# Exits 0 only if every Job succeeded. Callers decide what a failure means.
set -euo pipefail

timeout=$1
shift

declare -A short state seen
jobs=()
for arg in "$@"; do
  job=${arg%%=*}
  node=${arg#*=}
  jobs+=("$job")
  # lke86850-757936-31c4f0d50000 -> 31c4f0d5
  short[$job]=${node##*-}
  short[$job]=${short[$job]:0:8}
  state[$job]=pending
done

start=$SECONDS
last_said=$SECONDS
say() {
  local t=$((SECONDS - start))
  printf '%3d:%02d  %s\n' $((t / 60)) $((t % 60)) "$*"
  last_said=$SECONDS
}

# One TSV line per pull event of the given Jobs' pods: job, dedup key, text.
render_events() {
  jq -r --argjson pods "$1" '
    ($pods.items | map({key: .metadata.uid, value: .metadata.labels["job-name"]}) | from_entries) as $job
    | .items[]
    | select(.involvedObject.kind == "Pod" and $job[.involvedObject.uid] != null)
    | select(.reason | IN("Pulling", "Pulled", "Failed", "BackOff"))
    | ((.message | capture("\"(?<i>[^\"]+)\"")).i // "" | sub("^ghcr\\.io/starcitizentools/"; "")) as $img
    | (if .reason == "Pulling" then "pulling \($img)"
       elif .reason == "Pulled" and (.message | startswith("Successfully")) then
         "pulled  \($img) in \((.message | capture(" in (?<d>[0-9.hms]+) ")).d // "?")"
         + (((.message | capture("Image size: (?<b>[0-9]+) bytes")).b // null)
            | if . then ", \((tonumber / 1e7 | round) / 100) GB" else "" end)
       elif .reason == "Pulled" then "cached  \($img)"
       else "\(.reason): \(.message)" end) as $text
    | [$job[.involvedObject.uid], "\(.metadata.uid):\(.count // 1)", $text]
    | @tsv'
}

while :; do
  pods=$(kubectl get pods -l "job-name in ($(IFS=,; echo "${jobs[*]}"))" -o json)
  while IFS=$'\t' read -r job key text; do
    if [ -n "${short[$job]:-}" ] && [ -z "${seen[$key]:-}" ]; then
      seen[$key]=1
      say "${short[$job]}  $text"
    fi
  done < <(kubectl get events -o json | render_events "$pods")

  job_states=$(kubectl get jobs -o json)
  pending=()
  for job in "${jobs[@]}"; do
    if [ "${state[$job]}" = pending ]; then
      result=$(jq -r --arg j "$job" '.items[] | select(.metadata.name == $j)
        | if (.status.succeeded // 0) > 0 then "ok" elif (.status.failed // 0) > 0 then "failed" else "" end' <<<"$job_states")
      case $result in
        ok) state[$job]=ok; say "${short[$job]}  done" ;;
        failed) state[$job]=failed; say "${short[$job]}  pull pod failed" ;;
        *) pending+=("${short[$job]}") ;;
      esac
    fi
  done

  if [ ${#pending[@]} -eq 0 ]; then
    break
  fi
  if ((SECONDS - start >= timeout)); then
    say "gave up waiting on ${pending[*]}"
    break
  fi
  if ((SECONDS - last_said >= 30)); then
    say "still pulling on ${pending[*]}"
  fi
  sleep 5
done

for job in "${jobs[@]}"; do
  if [ "${state[$job]}" != ok ]; then
    exit 1
  fi
done
