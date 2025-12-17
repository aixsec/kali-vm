#!/bin/bash

set -e

# need ansifilter to post-process log files
if ! command -v ansifilter >/dev/null 2>&1; then
    echo "Please run: sudo apt install -y ansifilter" >&2
    exit 1
fi

# we dont want build.sh to automatically detect and use a proxy
export http_proxy=

logdir=testlogs-$(date +%s)
mkdir $logdir

{ time ./build.sh -m http://http.kali.org/kali; } 2>&1 | ansifilter | tee $logdir/build-prod.log
{ time ./build.sh -m http://http-staging.kali.org/kali; } 2>&1 | ansifilter | tee $logdir/build-staging.log

cd $logdir

grep ^Get: build-prod.log | cut -d' ' -f2 | cut -d/ -f3 | sort | uniq -c | sort -rn > pkgreq-prod.log
grep ^Get: build-staging.log | cut -d' ' -f2 | cut -d/ -f3 | sort | uniq -c | sort -rn > pkgreq-staging.log

cat << EOF
---------------------------------------

Done. Check $logdir for details.

PRODUCTION ****************************
-- requests
$(cat pkgreq-prod.log)
-- timing
$(tail -n 3 build-prod.log)

STAGING *******************************
-- requests
$(cat pkgreq-staging.log)
-- timing
$(tail -n 3 build-staging.log)

---------------------------------------
EOF
