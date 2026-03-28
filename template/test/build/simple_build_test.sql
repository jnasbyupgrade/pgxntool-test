/*
 * Verify the generated default_version (0.1.1) installs correctly.
 *
 * make generates pgxntool-test--0.1.1.sql from the base SQL and control
 * file, and 'make install' places it in the extension directory. CREATE
 * EXTENSION installs that version. We call the bigint overload because it
 * was added in the 0.1.0-to-0.1.1 upgrade, so its existence proves the
 * current version was installed rather than an older one.
 */
CREATE EXTENSION "pgxntool-test";
SELECT "pgxntool-test"(1::bigint, 2::bigint);
