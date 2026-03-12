set fn ../../home-manager/programs/fish/functions
source $fn/_hm_load_env_file.fish

set tmpdir (mktemp -d)

# ── KEY=VALUE ──────────────────────────────────────────────
printf "FOO=bar\n" > $tmpdir/t.env
set -x DOTFILES_ENV_FILE $tmpdir/t.env
_hm_load_env_file
@test "parses KEY=VALUE" $FOO = bar

# ── double-quoted value ────────────────────────────────────
printf 'QVAL="hello world"\n' > $tmpdir/t.env
set -x DOTFILES_ENV_FILE $tmpdir/t.env
_hm_load_env_file
@test "strips double quotes" $QVAL = "hello world"

# ── single-quoted value ────────────────────────────────────
printf "SVAL='single quoted'\n" > $tmpdir/t.env
set -x DOTFILES_ENV_FILE $tmpdir/t.env
_hm_load_env_file
@test "strips single quotes" $SVAL = "single quoted"

# ── export prefix ─────────────────────────────────────────
printf "export EXPKEY=expval\n" > $tmpdir/t.env
set -x DOTFILES_ENV_FILE $tmpdir/t.env
_hm_load_env_file
@test "strips export prefix" $EXPKEY = expval

# ── comment and blank lines ───────────────────────────────
printf "# comment\n\nBARK=baz\n" > $tmpdir/t.env
set -x DOTFILES_ENV_FILE $tmpdir/t.env
_hm_load_env_file
@test "skips comments" $BARK = baz

# ── missing env file ───────────────────────────────────────
set -e DOTFILES_ENV_FILE
set -x HOME $tmpdir
@test "returns 0 when no file" (_hm_load_env_file; echo done) = done

rm -rf $tmpdir
