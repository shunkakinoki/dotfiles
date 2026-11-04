# shellcheck shell=bash
# Rebuild records.db with only this host's records. Upload-only hosts never
# read other hosts' records, but a past full sync left tens of GB of them.

D="${XDG_DATA_HOME:-$HOME/.local/share}/atuin"
N="$D/records.slim.db"

[ -f "$D/records.db" ] || exit 0
ME=$(sqlite3 -readonly "file:$D/meta.db?mode=ro" "select value from meta where key='host_id'" |
  sed -E 's/^(.{8})(.{4})(.{4})(.{4})(.{12})$/\1-\2-\3-\4-\5/')
if [ -z "$ME" ]; then
  echo "no host_id"
  exit 1
fi

foreign=$(sqlite3 -readonly "file:$D/records.db?mode=ro" "select 1 from store where host <> '$ME' limit 1")
if [ -z "$foreign" ]; then
  echo "no foreign records"
  exit 0
fi

free_kb=$(df -Pk "$D" | awk 'NR==2 {print $4}')
if [ "$free_kb" -lt $((10 * 1024 * 1024)) ]; then
  echo "less than 10G free; skipping"
  exit 1
fi

per_tag="select tag||':'||count(*)||':'||max(idx) from store"
tables=$(sqlite3 -readonly "file:$D/records.db?mode=ro" "select sql||';' from sqlite_master where type='table' and name not like 'sqlite_%'")
indexes=$(sqlite3 -readonly "file:$D/records.db?mode=ro" "select sql||';' from sqlite_master where type='index' and sql is not null")

rm -f "$N" "$N-wal" "$N-shm"
# The bulk copy runs while the daemon is live; the swap below only adds the delta.
sqlite3 "$N" <<SQL
$tables
attach '$D/records.db' as old;
insert into main._sqlx_migrations select * from old._sqlx_migrations;
insert into main.store select * from old.store where host = '$ME';
detach old;
$indexes
SQL

trap 'systemctl --user start atuin-daemon.socket atuin-daemon.service atuin-push.timer' EXIT
systemctl --user stop atuin-push.timer atuin-push.service atuin-daemon.socket atuin-daemon.service
sleep 1
if pgrep -f 'atuin (daemon|store)' >/dev/null; then
  echo "atuin still running; aborting"
  rm -f "$N"
  exit 1
fi

sqlite3 "$N" <<SQL
attach '$D/records.db' as old;
insert or ignore into main.store
  select s.* from old.store s
  where s.host = '$ME'
    and s.idx > coalesce((select max(m.idx) from main.store m where m.host = s.host and m.tag = s.tag), -1);
SQL

new=$(sqlite3 "$N" "$per_tag group by tag order by tag")
old=$(sqlite3 -readonly "file:$D/records.db?mode=ro" "$per_tag where host='$ME' group by tag order by tag")
integrity=$(sqlite3 "$N" "pragma wal_checkpoint(truncate); pragma integrity_check;" | tail -1)
if [ "$new" != "$old" ] || [ "$integrity" != "ok" ]; then
  echo "verification failed; not swapping"
  echo "new: $new"
  echo "old: $old"
  echo "integrity: $integrity"
  rm -f "$N" "$N-wal" "$N-shm"
  exit 1
fi

# history.db and threads.db are projections of records.db; the rebuilds below
# recreate them from this host's records alone.
for db in records history threads; do
  for f in "$db.db" "$db.db-wal" "$db.db-shm"; do
    [ ! -e "$D/$f" ] || mv "$D/$f" "$D/$f.pre-prune"
  done
done
mv "$N" "$D/records.db"
rm -f "$N-wal" "$N-shm"

systemctl --user start atuin-daemon.socket atuin-daemon.service
sleep 5
atuin store rebuild history
atuin store rebuild threads
atuin store push

rm -f "$D"/*.pre-prune
echo "pruned: $new"
