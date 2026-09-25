#!/usr/bin/env bash
#
# tests/setup-local-file.sh - behaviour tests for how scripts/setup creates and fills in the local file (ADR 0002).
#
# Each case sources scripts/setup in a subshell with HOME and XDG_CONFIG_HOME inside a throwaway sandbox, so the real local file is never touched. `interactive` is overridden to stand in for a terminal, and answers come on stdin.
#
#   bash tests/setup-local-file.sh

set -Euo pipefail

readonly REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

passed=0
failed=0
sandbox=""

# ── Harness ───────────────────────────────────────────────────────────────
setup() {
  sandbox="$(mktemp -d)"
  [[ -d $sandbox ]] || {
    printf 'no sandbox\n' >&2
    exit 1
  }
  mkdir -p "${sandbox}/home"
  local_file="${sandbox}/config/dotfiles/local.yml"
  tty=0
  input=""
}

teardown() { rm -rf "$sandbox"; }

gitconfig() { printf '[user]\n\tname = %s\n\temail = %s\n' "$1" "$2" > "${sandbox}/home/.gitconfig"; }

# seed PROFILE NAME EMAIL LOGIN: a complete local file, as a previous run would have left it.
seed() {
  mkdir -p "$(dirname "$local_file")"
  printf 'dotfiles_profile: %s\ngit_user_name: "%s"\ngit_user_email: "%s"\ngit_user_login: "%s"\n' "$@" > "$local_file"
}

# run [SETUP-ARGS...]: parse the arguments and run ensure_local_file, as main would.
run() {
  out="$(
    cd "$sandbox" && env -u XDG_CONFIG_HOME -u GIT_CONFIG_GLOBAL \
      HOME="${sandbox}/home" XDG_CONFIG_HOME="${sandbox}/config" DOTFILES_DIR="$REPO" TTY="$tty" \
      bash -c '
        # shellcheck disable=SC1091 # sourced at runtime
        source "${DOTFILES_DIR}/scripts/setup"
        [[ $LOCAL_FILE == "${XDG_CONFIG_HOME}/"* ]] || { echo "LOCAL_FILE escaped the sandbox: $LOCAL_FILE"; exit 99; }
        interactive() { [[ $TTY == 1 ]]; }
        parse_args "$@"
        ensure_local_file
      ' -- "$@" <<< "$input" 2>&1
  )"
  status=$?
}

# value KEY: what scripts/setup itself reads back from the local file.
value() {
  env HOME="${sandbox}/home" XDG_CONFIG_HOME="${sandbox}/config" DOTFILES_DIR="$REPO" bash -c '
    # shellcheck disable=SC1091 # sourced at runtime
    source "${DOTFILES_DIR}/scripts/setup"
    local_get "$1"
  ' -- "$1"
}

fail() {
  printf '    %s\n' "$*"
  case_ok=0
}
expect_status() { [[ $status == "$1" ]] || fail "exit status ${status}, expected $1. Output:" "$out"; }
expect_output() { [[ $out == *"$1"* ]] || fail "output lacks '$1': $out"; }
expect_no_output() { [[ $out != *"$1"* ]] || fail "output has '$1': $out"; }
expect_value() {
  local got
  got="$(value "$1")"
  [[ $got == "$2" ]] || fail "$1 is '${got}', expected '$2'"
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
t_first_run_needs_profile_without_tty() {
  run
  expect_status 1
  expect_output "first run without a terminal"
  expect_absent "$local_file"
}

t_rejects_unknown_profile() {
  run --profile nope
  expect_status 1
  expect_output "no profile named 'nope'"
  run --profile base
  expect_status 1
}

t_seeds_without_tty() {
  run --profile work
  expect_status 0
  expect_value dotfiles_profile work
  expect_output "lacks git_user_name git_user_email"
  local mode
  mode="$(stat -c %a "$local_file")"
  [[ $mode == 600 ]] || fail "local file is mode ${mode}, expected 600"
}

t_seeds_identity_from_gitconfig() {
  gitconfig "Ann O'Neil | & /x" ann@example.com
  run --profile home
  expect_status 0
  expect_value git_user_name "Ann O'Neil | & /x"
  expect_value git_user_email ann@example.com
  expect_no_output "lacks"
}

t_asks_on_first_run() {
  tty=1
  input=$'work\nJane "J" \\ Doe\nnot-an-email\nj@example.com\njdoe\n'
  run
  expect_status 0
  expect_output "not a valid answer"
  expect_value dotfiles_profile work
  expect_value git_user_name 'Jane "J" \ Doe'
  expect_value git_user_email j@example.com
  expect_value git_user_login jdoe
  if python3 -c 'import yaml' 2> /dev/null; then
    python3 -c 'import sys, yaml; v = yaml.safe_load(open(sys.argv[1])); assert v["git_user_name"] == sys.argv[2], v' \
      "$local_file" 'Jane "J" \ Doe' || fail "the local file does not parse to the answers"
  fi
}

t_defaults_come_from_gitconfig() {
  tty=1
  gitconfig "Ann" ann@example.com
  input=$'home\n\n\n\n'
  run
  expect_status 0
  expect_value git_user_name Ann
  expect_value git_user_email ann@example.com
  expect_value git_user_login ""
}

t_asks_nothing_when_complete() {
  tty=1
  seed home Ann ann@example.com ann
  input=$'work\nBob\nbob@example.com\nbob\n'
  run
  expect_status 0
  expect_value dotfiles_profile home
  expect_value git_user_name Ann
}

t_asks_for_what_is_missing() {
  tty=1
  seed home Ann "" ann
  input=$'\n\nann@example.com\n\n'
  run
  expect_status 0
  expect_value git_user_email ann@example.com
  expect_value git_user_login ann
}

t_configure_asks_again() {
  tty=1
  seed home Ann ann@example.com ann
  input=$'work\n\n\n-\n'
  run --configure
  expect_status 0
  expect_value dotfiles_profile work
  expect_value git_user_name Ann
  expect_value git_user_login ""
}

t_configure_without_tty_warns() {
  seed home Ann ann@example.com ann
  run --configure
  expect_status 0
  expect_output "--configure needs a terminal"
  expect_value dotfiles_profile home
}

t_profile_flag_switches() {
  seed home Ann ann@example.com ann
  run --profile work
  expect_status 0
  expect_value dotfiles_profile work
  expect_value git_user_name Ann
}

t_eof_stops() {
  tty=1
  input=""
  run
  expect_status 1
  expect_output "no answer"
}

it "needs a profile on a first run without a terminal" t_first_run_needs_profile_without_tty
it "rejects an unknown profile" t_rejects_unknown_profile
it "seeds the local file without a terminal and warns" t_seeds_without_tty
it "seeds git identity from ~/.gitconfig" t_seeds_identity_from_gitconfig
it "asks for the core values on a first run" t_asks_on_first_run
it "offers ~/.gitconfig identity as the default" t_defaults_come_from_gitconfig
it "asks nothing when the local file is complete" t_asks_nothing_when_complete
it "asks when a value is missing" t_asks_for_what_is_missing
it "asks again with --configure" t_configure_asks_again
it "warns about --configure without a terminal" t_configure_without_tty_warns
it "switches the profile with --profile" t_profile_flag_switches
it "stops when the answers run out" t_eof_stops

printf '\n%d passed, %d failed\n' "$passed" "$failed"
((failed == 0))
