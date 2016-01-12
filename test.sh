#!/bin/bash

trap 'echo "$BASH_SOURCE: line $LINENO" >&2' ERR
set -o errexit -o errtrace -o pipefail
#set -o xtrace -o verbose

PGXNBRANCH=${PGXNBRANCH:-${1:-master}}
PGXNREPO=${PGXNREPO:-${2:-${0%/*}/../pgxntool}}
TEST_TEMPLATE=${TEST_TEMPLATE:-${0%/*}/../pgxntool-test-template}

find_repo () {
  if ! echo $1 | egrep -q '^(git|https?):'; then
    cd $1
    pwd
  fi
}

TEST_TEMPLATE=`find_repo $TEST_TEMPLATE`
PGXNREPO=`find_repo $PGXNREPO`

TMPDIR=${TMPDIR:-${TEMP:-$TMP}}
TEST_DIR=`mktemp -d -t pgxntool-test.XXXXXX`
[ $? -eq 0 ] || exit 1
trap "echo cd $TEST_DIR" EXIT

git clone $TEST_TEMPLATE $TEST_DIR
cd $TEST_DIR
git subtree add -P pgxntool --squash $PGXNREPO $PGXNBRANCH
pgxntool/setup.sh
ls
git status
git diff
git commit -am "Test setup"

make pgtap || exit 1

make || exit 1

# vi: expandtab sw=2 ts=2
