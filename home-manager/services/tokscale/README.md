# Tokscale scheduled uploads

Home Manager runs `submit.sh` every three hours on Linux and macOS. The
installation of Tokscale remains unchanged.

Before uploading, `sync-cursor.py` checks each saved Cursor account's cache.
Missing or unverified caches are rebuilt from disjoint date ranges of at most
25,000 events. Each range is paginated to its advertised total, and the complete
account cache is published atomically only after all counts match. An existing
cache is preserved under `cursor-cache/archive/` before replacement.

Routine refreshes use Tokscale's native incremental sync. If a long gap exceeds
its download byte or page limit, the same chunked rebuild recovers the account.
Incomplete downloads never replace the cache. Uploads of available data still
run, but a failed Cursor refresh makes the scheduled job fail visibly.

The helper reads saved credentials directly and sends the cookie in HTTP
headers; it never passes the cookie through process arguments. It honors
`TOKSCALE_CONFIG_DIR` and `XDG_CONFIG_HOME` like Tokscale.

Cursor authentication still needs a valid saved session. Run
`tokscale cursor status` to check it and `tokscale cursor login` to renew it.
The job does not prompt for credentials. Logs are in `/tmp/tokscale.log` and
`/tmp/tokscale.error.log`.
