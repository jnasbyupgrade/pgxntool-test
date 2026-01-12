/*
 * Upgrade from 0.1.0 to 0.1.1
 * Adds a bigint version of the pgxntool-test function
 */

CREATE FUNCTION "pgxntool-test"(
  a bigint
  , b bigint
) RETURNS bigint LANGUAGE sql IMMUTABLE AS $body$
SELECT $1 + $2 -- 9.1 doesn't support named sql language parameters
$body$;

-- vi: expandtab ts=2 sw=2
