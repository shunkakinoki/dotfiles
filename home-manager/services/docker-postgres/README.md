# Local Postgres

The managed database publishes only `127.0.0.1:5432`. New databases use SCRAM
authentication, a protected password file, and the named `postgres-data` volume.
The password file defaults to `$XDG_STATE_HOME/docker-postgres/password`, or
`~/.local/state/docker-postgres/password` when XDG_STATE_HOME is unset. Set
`POSTGRES_PASSWORD_FILE` to use an existing protected file, and
`POSTGRES_DATA_VOLUME` to reuse an existing Docker volume.

An existing container with unrestricted publishing or trust authentication is
reported as an error and left intact. Routine startup never deletes, recreates,
or migrates an existing database. Health checks also reject live network trust
rules and authentication-rule inspection failures.

## Migrate an existing database

Use a maintenance window and update dependent clients to use the new credential.
Stop the service supervisor first so it cannot race the manual migration. Keep
the original container and a verified database backup until acceptance succeeds.

1. Inspect the existing container's image and mounts. Record the data volume and
   mount destination. The steps below apply to PostgreSQL 18 with a Docker
   volume mounted at `/var/lib/postgresql`; stop if the layout differs.
2. With a restrictive umask, save `docker exec postgres pg_dumpall -U postgres`
   to a private backup file. Verify the backup before proceeding.
3. Generate a random password into the protected password file. Set the database
   role's password using `docker exec -it postgres psql -U postgres -d postgres`
   and `\password postgres`; do not put the password in command arguments or logs.
4. Back up the file returned by `SHOW hba_file`. Replace network `trust` rules
   with `scram-sha-256`, reload the configuration, and verify
   `pg_hba_file_rules` contains no invalid or network trust entries. The local
   Unix-socket authentication used by administrative health checks can remain.
5. Stop the container and rename it to `postgres-before-hardening`. Do not remove
   its volume, prune volumes, or delete its data directory.
6. Run `start-postgres.sh` with `POSTGRES_DATA_VOLUME` set to the recorded volume
   and `POSTGRES_PASSWORD_FILE` set to the protected file. This starts a replacement
   container attached to the same data, with loopback publishing. PostgreSQL init
   environment variables do not change authentication in an existing data volume;
   that is why the role and HBA changes precede this step.
7. Verify the loopback binding, authenticated client access, rejection of a
   passwordless TCP connection, application behavior, and the original data.
   Re-enable the supervisor only after these checks pass.

For rollback, stop the replacement before starting the retained container, and
attach the volume to only one running PostgreSQL process. Retain SCRAM and the
new credential rather than restoring trust authentication.
