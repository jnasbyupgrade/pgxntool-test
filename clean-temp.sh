#!/usr/bin/env bash

trap 'echo "$BASH_SOURCE: line $LINENO" >&2' ERR
set -o errexit -o errtrace -o pipefail

BASEDIR=`cd ${0%/*}; pwd`

. $BASEDIR/.env

rm -rf $RESULT_DIR
rm $BASEDIR/.env
