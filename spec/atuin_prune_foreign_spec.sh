#!/usr/bin/env bash
# shellcheck disable=SC2016,SC2329

Describe 'home-manager/programs/atuin/prune-foreign.sh'
SCRIPT="$PWD/home-manager/programs/atuin/prune-foreign.sh"
ME_RAW=01a0c71d03427b6181ab845233ba22cc
ME=01a0c71d-0342-7b61-81ab-845233ba22cc

setup() {
  TMP="$(mktemp -d)"
  export XDG_DATA_HOME="$TMP/data"
  D="$XDG_DATA_HOME/atuin"
  mkdir -p "$D" "$TMP/bin"
  for cmd in systemctl atuin; do
    printf '#!/usr/bin/env bash\necho "%s $*" >>"%s/calls"\n' "$cmd" "$TMP" >"$TMP/bin/$cmd"
  done
  printf '#!/usr/bin/env bash\nexit 1\n' >"$TMP/bin/pgrep"
  printf '#!/usr/bin/env bash\n' >"$TMP/bin/sleep"
  printf '#!/usr/bin/env bash\necho header\necho "fs 1 1 99999999 1%% /"\n' >"$TMP/bin/df"
  chmod +x "$TMP"/bin/*
  touch "$TMP/calls"
}
cleanup() { rm -rf "$TMP"; }
BeforeEach 'setup'
AfterEach 'cleanup'

no_sqlite() { ! command -v sqlite3 >/dev/null; }

seed() {
  sqlite3 "$D/meta.db" "create table meta(key text primary key, value text); insert into meta values('host_id', '$ME_RAW');"
  sqlite3 "$D/records.db" <<SQL
create table _sqlx_migrations(version integer primary key);
insert into _sqlx_migrations values (1);
create table store(id text primary key, idx integer, host text, tag text, timestamp integer, version text, data blob, cek blob);
create unique index record_uniq on store(host, tag, idx);
insert into store values ('a', 0, '$ME', 'history', 1, 'v0', 'x', 'k');
insert into store values ('b', 1, '$ME', 'history', 2, 'v0', 'x', 'k');
insert into store values ('c', 0, 'other', 'history', 1, 'v0', 'x', 'k');
SQL
  echo old >"$D/history.db"
  echo old >"$D/threads.db"
}

run_script() { PATH="$TMP/bin:$PATH" bash "$SCRIPT"; }

It 'exits cleanly without a records store'
When call run_script
The status should be success
The contents of file "$TMP/calls" should equal ''
End

It 'is a no-op when only this host has records'
Skip if 'sqlite3 is not installed' no_sqlite
seed
sqlite3 "$D/records.db" "delete from store where host = 'other'"
When call run_script
The status should be success
The output should equal 'no foreign records'
The contents of file "$TMP/calls" should equal ''
End

It 'skips when disk space is low'
Skip if 'sqlite3 is not installed' no_sqlite
seed
printf '#!/usr/bin/env bash\necho header\necho "fs 1 1 1024 1%% /"\n' >"$TMP/bin/df"
When call run_script
The status should be failure
The output should equal 'less than 10G free; skipping'
The value "$(sqlite3 "$D/records.db" 'select count(*) from store')" should equal 3
End

It 'keeps only this host records and rebuilds projections'
Skip if 'sqlite3 is not installed' no_sqlite
seed
When call run_script
The status should be success
The output should equal 'pruned: history:2:1'
The value "$(sqlite3 "$D/records.db" 'select group_concat(id) from store order by id')" should equal 'a,b'
The value "$(sqlite3 "$D/records.db" 'select count(*) from _sqlx_migrations')" should equal 1
The path "$D/history.db" should not be exist
The path "$D/threads.db" should not be exist
The path "$D/records.db.pre-prune" should not be exist
The contents of file "$TMP/calls" should include 'atuin store rebuild history'
The contents of file "$TMP/calls" should include 'atuin store rebuild threads'
The contents of file "$TMP/calls" should include 'atuin store push'
The contents of file "$TMP/calls" should include 'systemctl --user start atuin-daemon.socket atuin-daemon.service atuin-push.timer'
End

It 'refuses to swap in an empty store'
Skip if 'sqlite3 is not installed' no_sqlite
seed
sqlite3 "$D/records.db" "delete from store where host = '$ME'"
When call run_script
The status should be failure
The output should include 'verification failed; not swapping'
The value "$(sqlite3 "$D/records.db" 'select count(*) from store')" should equal 1
End

It 'resumes the rebuild after a failed run'
seed_backup() {
  echo new >"$D/records.db"
  echo old >"$D/records.db.pre-prune"
  echo old >"$D/threads.db.pre-prune"
}
seed_backup
When call run_script
The status should be success
The output should equal 'resumed pending rebuild'
The path "$D/records.db.pre-prune" should not be exist
The path "$D/threads.db.pre-prune" should not be exist
The contents of file "$TMP/calls" should include 'atuin store rebuild threads'
End

It 'rolls back an interrupted swap'
Skip if 'sqlite3 is not installed' no_sqlite
seed
mv "$D/records.db" "$D/records.db.pre-prune"
mv "$D/history.db" "$D/history.db.pre-prune"
When call run_script
The status should be success
The output should equal 'pruned: history:2:1'
The value "$(sqlite3 "$D/records.db" 'select group_concat(id) from store order by id')" should equal 'a,b'
The path "$D/records.db.pre-prune" should not be exist
End

It 'aborts the swap while atuin is still running'
Skip if 'sqlite3 is not installed' no_sqlite
seed
printf '#!/usr/bin/env bash\nexit 0\n' >"$TMP/bin/pgrep"
When call run_script
The status should be failure
The output should equal 'atuin still running; aborting'
The value "$(sqlite3 "$D/records.db" 'select count(*) from store')" should equal 3
The path "$D/records.slim.db" should not be exist
The contents of file "$TMP/calls" should include 'systemctl --user start atuin-daemon.socket'
End
End
