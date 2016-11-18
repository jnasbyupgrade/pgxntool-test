#!/bin/bash

head_log() {
    echo "$@" 1>&2
    echo $0: head $LOG 1>&2
    head $LOG >&2
    echo $0: END LOG 1>&2
    echo '' 1>&2
}

find_repo () {
  if ! echo $1 | egrep -q '^(git|https?):'; then
    cd $1
    pwd
  fi
}
out () {
  if [ "$1" == "-v" ]; then
    local verbose=1
    shift
  fi

  # NOTE: Thes MUST be error condition tests (|| instead of &&) or else our ERR trap will fire and we'll exit
  [ -z "$verbose" ] || echo '######################################'
  echo '#' $*

  # If we were passed verbose output then don't output unless in verbose mode.
  # Remember we need to invert everything because of ||
  [ -n "$verbose" -a -z "$verboseout" ] || echo '#' $* >&8
  [ -z "$verbose" ] || echo '######################################'
}

clean_log () {
  # Need to strip out temporary path and git hashes out of the log file. The
  # (/private) bit is to filter out some crap OS X adds.
  sed -i .bak -E \
    -e "s#(/private)\\\\?$TEST_DIR#@TEST_DIR@#g" \
    -e "s#^git fetch $PGXNREPO $PGXNBRANCH#git fetch @PGXNREPO@ @PGXNBRANCH@#" \
    -e "s#$PG_LOCATION#@PG_LOCATION@#g" \
    -f $RESULT_DIR/result.sed \
    $LOG
}

check_log() {
  reset_redirect
  clean_log
}

redirect() {
  # Don't bother if $LOG isn't set
  if [ -z "$LOG" ]; then
    echo '$LOG is not set; not redirecting output'
    return
  fi

  # See http://unix.stackexchange.com/questions/206786/testing-if-a-file-descriptor-is-valid
  if ! { true >&8; } 2>&-; then
    # Save stdout & stderr
    exec 8>&1
    exec 9>&2
    if [ -z "$verboseout" ]; then
  #wc $LOG
      exec >> $LOG
  #wc $LOG >&8
    else
      # Redirect STDOUT to a subproc http://stackoverflow.com/questions/3173131/redirect-copy-of-stdout-to-log-file-from-within-bash-script-itself
      exec > >(tee -ai $LOG)
    fi

    # Always have errors go to both places
    exec 2> >(tee -ai $LOG >&9)
  fi
}

reset_redirect() {
  if { true >&8; } 2>&-; then
    # Restore stdout and close FD #8. Ditto with stderr
    exec >&8 8>&-
    exec 2>&9 9>&-
  fi
}

PGXNBRANCH=${PGXNBRANCH:-${1:-master}}
PGXNREPO=${PGXNREPO:-${2:-${TOPDIR}/../pgxntool}}
TEST_TEMPLATE=${TEST_TEMPLATE:-${TOPDIR}/../pgxntool-test-template}
TEST_REPO=$TEST_DIR/repo

PG_LOCATION=`pg_config --bindir | sed 's#/bin##'`
PGXNREPO=`find_repo $PGXNREPO`
TEST_TEMPLATE=`find_repo $TEST_TEMPLATE`

redirect

#trap "echo PTD='$TEST_DIR' >&2; echo LOG='$LOG' >&2" EXIT

#head_log 'from lib.sh'

# vi: expandtab sw=2 ts=2