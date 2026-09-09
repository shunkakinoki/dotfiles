# Called by managed shell init with systemd-run, fish and false binaries.
if not set -q HERDR_ENV; or not status is-interactive
    return
end

if set -q HERDR_PANE_ROLE; and test "$HERDR_PANE_ROLE" != recovery
    echo 'Unknown Herdr pane role; refusing pane launch.' >&2
    exec $argv[3]
end

if set -q HERDR_PANE_SCOPED
    return
end

if not test -r /proc/self/cgroup
    echo 'Herdr pane cgroup is unavailable; refusing unverified placement.' >&2
    exec $argv[3]
end
set -l current_cgroup (cat /proc/self/cgroup)

# An operator-moved recovery worker may predate the launch-role variable.
if string match -q '*/herdr.slice/herdr-recovery-*.scope' $current_cgroup
    set -gx HERDR_PANE_ROLE recovery
    set -gx HERDR_PANE_SCOPED 1
    return
end

set -l pane_slice orchestration.slice
set -l pane_unit herdr-pane
if set -q HERDR_PANE_ROLE
    set pane_slice herdr.slice
    set pane_unit herdr-recovery
end

# Existing scoped panes keep their placement when their shell is replaced.
if string match -q "*/$pane_slice/$pane_unit-*.scope" $current_cgroup
    return
end

set -gx HERDR_PANE_SCOPED 1
exec $argv[1] --user --quiet --scope --collect \
    --slice=$pane_slice --unit=$pane_unit-$fish_pid $argv[2]
