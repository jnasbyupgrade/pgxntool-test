#!/bin/sh

# If you add anything here make sure to look at clean-temp.sh as well
 
TOPDIR=`cd ${0%/*}; pwd`

TMPDIR=${TMPDIR:-${TEMP:-${TMP:-/tmp/}}}
TEST_DIR=`_CS_DARWIN_USER_TEMP_DIR=$TMPDIR; mktemp -d $TMPDIR/pgxntool-test.XXXXXX`
[ $? -eq 0 ] || exit 1

echo "TOPDIR='$TOPDIR'"
echo "TEST_DIR='$TEST_DIR'"
