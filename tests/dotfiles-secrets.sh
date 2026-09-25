#!/usr/bin/env bash
#
# tests/dotfiles-secrets.sh - behaviour tests for roles/secrets/files/dotfiles-secrets (ADR 0012).
#
# Each case runs the script against a throwaway HOME, with a stub `infisical` on PATH, so nothing touches the network or the real home directory.
#
#   bash tests/dotfiles-secrets.sh

set -Euo pipefail

readonly SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/roles/secrets/files/dotfiles-secrets"
readonly HEADER="# Managed by dotfiles-secrets. Edit the secret at its source; the next sync overwrites this file."

passed=0
failed=0
sandbox=""

# ── Harness ───────────────────────────────────────────────────────────────
setup() {
  sandbox="$(mktemp -d)"
  export HOME="${sandbox}/home"
  # The cache normally lives in /dev/shm; the override keeps each case's cache inside its sandbox.
  export DOTFILES_SECRETS_CACHE_DIR="${sandbox}/cache"
  mkdir -p "$HOME/.config/dotfiles" "${sandbox}/bin"
  export PATH="${sandbox}/bin:${PATH}"
  unset FAKE_INFISICAL_DOWN
  git config --global user.name test 2> /dev/null || true

  # The stub: login answers with a token only for the right credentials; export needs that token and echoes what it was asked for.
  cat > "${sandbox}/bin/infisical" << 'EOF'
#!/usr/bin/env bash
cmd="$1"
shift
case "$cmd" in
  login)
    [[ ${FAKE_INFISICAL_DOWN:-0} == 1 ]] && { echo "network down" >&2; exit 1; }
    [[ $INFISICAL_UNIVERSAL_AUTH_CLIENT_ID == id-1 && $INFISICAL_UNIVERSAL_AUTH_CLIENT_SECRET == secret-1 ]] || { echo "bad credentials" >&2; exit 1; }
    printf 'tok-123\n'
    ;;
  export)
    [[ ${FAKE_INFISICAL_DOWN:-0} == 1 ]] && { echo "network down" >&2; exit 1; }
    [[ ${INFISICAL_TOKEN:-} == tok-123 ]] || { echo "no token" >&2; exit 1; }
    for arg in "$@"; do
      case "$arg" in
        --projectId=* | --env=* | --path=* | --format=*) printf '# %s\n' "$arg" ;;
      esac
    done
    printf "FROM_INFISICAL='yes'\n"
    ;;
  *) exit 2 ;;
esac
EOF
  chmod +x "${sandbox}/bin/infisical"
}

teardown() {
  chmod -R u+w "$sandbox" 2> /dev/null || true
  rm -rf "$sandbox"
}

# config SOURCE [TARGET-LINE...]: write the config the role would render.
config() {
  local source="$1"
  shift
  {
    printf 'source=%s\n' "$source"
    printf 'project=proj-1\n'
    printf 'local_dir=%s\n' "$HOME/.config/dotfiles/secrets"
    printf 'credentials=%s\n' "$HOME/.config/infisical/universal-auth"
    local target
    for target in "$@"; do
      printf 'target=%s\n' "$target"
    done
  } > "$HOME/.config/dotfiles/secrets.conf"
}

credentials() {
  mkdir -p "$HOME/.config/infisical"
  printf 'INFISICAL_UNIVERSAL_AUTH_CLIENT_ID=id-1\nINFISICAL_UNIVERSAL_AUTH_CLIENT_SECRET=secret-1\n' > "$HOME/.config/infisical/universal-auth"
  chmod 0600 "$HOME/.config/infisical/universal-auth"
}

local_secret() { # NAME CONTENT
  mkdir -p "$HOME/.config/dotfiles/secrets"
  printf '%s\n' "$2" > "$HOME/.config/dotfiles/secrets/$1.env"
}

# An ignored .env in a fresh git repo; prints the .env path.
project() {
  local dir="${sandbox}/proj-$1"
  mkdir -p "$dir"
  git -C "$dir" init -q
  [[ ${2:-ignored} == ignored ]] && printf '.env\n' > "$dir/.gitignore"
  printf '%s/.env' "$dir"
}

shell_cache() { printf '%s/shell.env' "$DOTFILES_SECRETS_CACHE_DIR"; }

run() {
  out="$("$SCRIPT" "$@" 2>&1)"
  status=$?
}

fail() {
  printf '    %s\n' "$*"
  case_ok=0
}
expect_status() { [[ $status == "$1" ]] || fail "exit status ${status}, expected $1. Output:" "$out"; }
expect_output() { [[ $out == *"$1"* ]] || fail "output lacks '$1': $out"; }
expect_file_has() { grep -qF -- "$2" "$1" 2> /dev/null || fail "$1 lacks '$2'"; }
expect_mode() {
  local mode
  mode="$(stat -c %a "$1" 2> /dev/null)"
  [[ $mode == "$2" ]] || fail "$1 is mode ${mode:-missing}, expected $2"
}
expect_absent() { [[ ! -e $1 ]] || fail "$1 exists"; }

it() {
  local name="$1"
  shift
  case_ok=1
  setup
  "$@"
  teardown
  if ((case_ok)); then
    passed=$((passed + 1))
    printf 'ok   %s\n' "$name"
  else
    failed=$((failed + 1))
    printf 'FAIL %s\n' "$name"
  fi
}

# ── Cases ─────────────────────────────────────────────────────────────────
t_missing_config() {
  run sync
  expect_status 1
  expect_output "secrets.conf"
}

t_local_shell() {
  config local "shell	shell	dev	/"
  local_secret shell "GITHUB_TOKEN=abc"
  run sync
  expect_status 0
  expect_output "updated shell"
  expect_file_has "$(shell_cache)" "$HEADER"
  expect_file_has "$(shell_cache)" "GITHUB_TOKEN=abc"
  expect_mode "$(shell_cache)" 600
  expect_mode "$(dirname "$(shell_cache)")" 700
}

t_idempotent() {
  config local "shell	shell	dev	/"
  local_secret shell "GITHUB_TOKEN=abc"
  run sync
  run sync
  expect_status 0
  expect_output "unchanged shell"
}

t_local_project() {
  local dest
  dest="$(project a)"
  config local "app	${dest}	dev	/"
  local_secret app "DB_PASSWORD=pw"
  run sync
  expect_status 0
  expect_output "updated app"
  expect_file_has "$dest" "$HEADER"
  expect_file_has "$dest" "DB_PASSWORD=pw"
  expect_mode "$dest" 600
}

t_refuses_tracked_env() {
  local dest
  dest="$(project b tracked)"
  config local "app	${dest}	dev	/"
  local_secret app "DB_PASSWORD=pw"
  run sync
  expect_status 1
  expect_output "not ignored by git"
  expect_absent "$dest"
}

t_backs_up_hand_made_env() {
  local dest
  dest="$(project c)"
  printf 'OLD=1\n' > "$dest"
  config local "app	${dest}	dev	/"
  local_secret app "NEW=2"
  run sync
  expect_status 0
  expect_file_has "${dest}.pre-dotfiles" "OLD=1"
  expect_file_has "$dest" "NEW=2"
}

t_never_clobbers_backup() {
  local dest
  dest="$(project d)"
  printf 'OLD=1\n' > "$dest"
  printf 'OLDER=0\n' > "${dest}.pre-dotfiles"
  config local "app	${dest}	dev	/"
  local_secret app "NEW=2"
  run sync
  expect_status 1
  expect_file_has "$dest" "OLD=1"
  expect_file_has "${dest}.pre-dotfiles" "OLDER=0"
}

t_missing_local_file() {
  config local "shell	shell	dev	/"
  run sync
  expect_status 1
  expect_output "shell.env"
}

t_infisical() {
  local dest
  dest="$(project e)"
  credentials
  config infisical "shell	shell	prod	/shell" "app	${dest}	dev	/app"
  run sync
  expect_status 0
  expect_file_has "$(shell_cache)" "FROM_INFISICAL='yes'"
  expect_file_has "$(shell_cache)" "--env=prod"
  expect_file_has "$(shell_cache)" "--path=/shell"
  expect_file_has "$(shell_cache)" "--format=dotenv-export"
  expect_file_has "$dest" "--env=dev"
  expect_file_has "$dest" "--path=/app"
  expect_file_has "$dest" "--projectId=proj-1"
  expect_file_has "$dest" "--format=dotenv"
}

# An outage leaves the last good copy in place.
t_infisical_down_keeps_files() {
  local dest
  dest="$(project f)"
  credentials
  config infisical "app	${dest}	dev	/app"
  run sync
  export FAKE_INFISICAL_DOWN=1
  run sync
  expect_status 1
  expect_output "failed app"
  expect_file_has "$dest" "FROM_INFISICAL='yes'"
}

# The backup of a hand-made .env happens only once there is something to replace it with.
t_failed_fetch_keeps_hand_made_env() {
  local dest
  dest="$(project h)"
  printf 'OLD=1\n' > "$dest"
  credentials
  config infisical "app	${dest}	dev	/app"
  export FAKE_INFISICAL_DOWN=1
  run sync
  expect_status 1
  expect_file_has "$dest" "OLD=1"
  expect_absent "${dest}.pre-dotfiles"
}

# Explicit source: a missing credential is an error, never a fall back to the local files.
t_no_fallback_to_local() {
  config infisical "shell	shell	dev	/"
  local_secret shell "LOCAL=1"
  run sync
  expect_status 1
  expect_output "universal-auth"
  expect_absent "$(shell_cache)"
}

t_shell_only() {
  local dest
  dest="$(project g)"
  config local "shell	shell	dev	/" "app	${dest}	dev	/"
  local_secret shell "S=1"
  local_secret app "A=1"
  run sync --shell
  expect_status 0
  expect_file_has "$(shell_cache)" "S=1"
  expect_absent "$dest"
}

t_path() {
  run path
  expect_status 0
  [[ $out == "$(shell_cache)" ]] || fail "path printed '$out', expected '$(shell_cache)'"
}

it "fails without a config" t_missing_config
it "writes the shell cache from the local source" t_local_shell
it "reports an unchanged target" t_idempotent
it "writes a project .env from the local source" t_local_project
it "refuses a .env that git does not ignore" t_refuses_tracked_env
it "backs up a hand-made .env once" t_backs_up_hand_made_env
it "never overwrites an earlier backup" t_never_clobbers_backup
it "fails when a local secrets file is missing" t_missing_local_file
it "fetches each target from Infisical" t_infisical
it "keeps the last good file when Infisical is down" t_infisical_down_keeps_files
it "keeps a hand-made .env when the fetch fails" t_failed_fetch_keeps_hand_made_env
it "does not fall back to local files without credentials" t_no_fallback_to_local
it "writes only the shell target with --shell" t_shell_only
it "prints the shell cache path" t_path

printf '\n%d passed, %d failed\n' "$passed" "$failed"
((failed == 0))
