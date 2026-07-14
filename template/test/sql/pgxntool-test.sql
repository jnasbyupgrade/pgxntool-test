\set ECHO none
-- DO NOT REMOVE: pg_regress runs psql with echo-all, so without this every
-- input line (including all of setup.sql) is echoed into the output and never
-- matches expected/pgxntool-test.out. This mirrors the standard pgxntool pgtap
-- convention (every test file starts with \set ECHO none).
\i test/pgxntool/setup.sql

SELECT plan(1);

SELECT is(
  "pgxntool-test"(1,2)
  , 3
);

\i test/pgxntool/finish.sql

-- vi: expandtab ts=2 sw=2
