#!/bin/sh
# Shared step runner for the MediaWiki maintenance cronjobs.
#
# The jobs' steps are independent -- none consumes what the previous one
# produces -- so a && chain is wrong: one failure cancels every step behind it
# and logs nothing about them. A `;` chain is also wrong: it hides the failure.
# Run every step, report each, fail the Job at the end if any hard step failed.
#
# Source with: . /scripts/_maintenance.sh

fail=0

# run <label> <maintenance script> [args...]  -- a failure fails the Job
run() {
  name=$1
  shift
  echo "::: $name"
  if php /var/www/mediawiki/maintenance/run.php "$@"; then
    echo "::: $name OK"
  else
    rc=$?
    echo "::: $name FAILED (exit $rc)"
    fail=1
  fi
}

# run_soft <label> <maintenance script> [args...]  -- a failure is reported but
# does NOT fail the Job. Only for steps whose non-zero exit is expected and
# benign; say why at each call site.
run_soft() {
  name=$1
  shift
  echo "::: $name"
  if php /var/www/mediawiki/maintenance/run.php "$@"; then
    echo "::: $name OK"
  else
    rc=$?
    echo "::: $name exited $rc (tolerated, not failing the job)"
  fi
}

finish() {
  if [ "$fail" -ne 0 ]; then
    echo "::: one or more steps failed"
  else
    echo "::: all steps OK"
  fi
  exit "$fail"
}
