# Git commit messages - handle any branch name
s/^\[[a-z0-9_-]+ [0-9a-f]+\]/@GIT COMMIT@/

# Git branch names - normalize to @BRANCH@
s/(branch|Branch) '?[a-z0-9_-]+'? set up to track( remote branch [a-z0-9_-]+ from origin| 'origin\/[a-z0-9_-]+')\.?/@BRANCH@ set up to track 'origin\/@BRANCH@'./g
s/\* \[new branch\] +[a-z0-9_-]+ -> [a-z0-9_-]+/* [new branch] @BRANCH@ -> @BRANCH@/
s/On branch [a-z0-9_-]+/On branch @BRANCH@/
s/ahead of 'origin\/[a-z0-9_-]+'/ahead of 'origin\/@BRANCH@'/
s/ \* branch +[a-z0-9_-]+ +-> FETCH_HEAD/ * branch @BRANCH@ -> FETCH_HEAD/

# Normalize environment-specific paths
s#/Users/[^/]+/#/Users/@USER@/#g
s#/(opt/local|opt/homebrew|usr/local)/bin/(asciidoc|asciidoctor)#/@ASCIIDOC_PATH@#g

# PostgreSQL test timing - strip millisecond output
s/(test [^.]+\.\.\.) (ok|FAILED)[ ]+[0-9]+ ms/\1 \2/

# PostgreSQL pg_regress connection info - normalize to just "(using postmaster on XXXX)"
s/\(using postmaster on [^)]+\)/(using postmaster on XXXX)/

# PostgreSQL plpgsql installation (only on PG < 13) - remove these lines
/^============== installing plpgsql/d
/^CREATE LANGUAGE$/d

# Normalize diff headers (old *** format vs new unified diff format)
s#^\*\*\* @TEST_DIR@#--- @TEST_DIR@#
s#^--- @TEST_DIR@/[^/]+/test/expected#--- @TEST_DIR@/repo/test/expected#
s#^\+\+\+ @TEST_DIR@/[^/]+/test/results#++++ @TEST_DIR@/repo/test/results#
s#^diff -U3 @TEST_DIR@.*#diff output normalized#

# Rsync output normalization
s!.*kB/s.*\(xfr#.*to-chk=.*\)!RSYNC OUTPUT!
s/^set [,0-9]{4,5} bytes.*/RSYNC OUTPUT/
s/^Transfer starting: .*/RSYNC TRANSFER/
s/^sent [0-9]+ bytes  received [0-9]+ bytes.*/RSYNC STATS/
s/^total size is [0-9]+  speedup is.*/RSYNC STATS/
s/^[ ]*[0-9]+[ ]+[0-9]+%[ ]+[0-9.]+[KMG]B\/s.*/RSYNC OUTPUT/

# File paths and locations
s/(@TEST_DIR@[^[:space:]]*).*:.*:.*/\1/
s/(LOCATION:  [^,]+, [^:]+:).*/\1####/
s#@PG_LOCATION@/lib/pgxs/src/makefiles/../../src/test/regress/pg_regress.*#INVOCATION OF pg_regress#
s#((/bin/sh )?@PG_LOCATION@/lib/pgxs/src/makefiles/../../config/install-sh)|(/usr/bin/install)#@INSTALL@#

# Clean up multiple slashes
s#([^:])//+#\1/#g

