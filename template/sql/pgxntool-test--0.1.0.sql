CREATE FUNCTION "pgxntool-test"(
  a int
  , b int
) RETURNS int LANGUAGE sql IMMUTABLE AS $body$
SELECT $1 + $2 -- 9.1 doesn't support named sql language parameters
$body$;

-- vi: expandtab ts=2 sw=2
