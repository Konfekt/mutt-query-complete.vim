#!/bin/sh
# Run the test suite in every editor given (default: vim, then nvim if found).
#   test/run.sh [vim|nvim|/path/to/editor ...]
set -u
root=$(cd "$(dirname "$0")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

if [ $# -eq 0 ]; then
  set -- vim
  command -v nvim >/dev/null 2>&1 && set -- "$@" nvim
fi

status=0

# run NAME EDITOR SCRIPT [ENV=VALUE ...]: run SCRIPT in EDITOR and report.
run() {
  name=$1 editor=$2 script=$3
  shift 3
  out=$tmp/out
  rm -f "$out"
  case $(basename "$editor") in
    nvim*) set -- env "$@" MQ_OUT="$out" "$editor" -u NONE -i NONE --headless -n -S "$script" ;;
    *) set -- env "$@" MQ_OUT="$out" "$editor" -u NONE -N -n -i NONE -Es -S "$script" ;;
  esac
  if "$@" </dev/null >/dev/null 2>&1 && [ "$(cat "$out" 2>/dev/null)" = PASS ]; then
    echo "ok   $name"
  else
    echo "FAIL $name"
    sed 's/^/     /' "$out" 2>/dev/null
    status=1
  fi
}

# A PATH with the stand-in query command but no mutt or neomutt.
nomutt=$tmp/nomutt
mkdir -p "$nomutt" "$tmp/home"
ln -s "$root/test/bin/mq-query" "$nomutt/mq-query"

for editor in "$@"; do
  ed=$(basename "$editor")
  editor=$(command -v "$editor") || { echo "FAIL $ed: not found"; status=1; continue; }
  run "$ed complete" "$editor" "$root/test/complete.vim"
  printf 'set query_command="mq-query --flag %%s"\n' > "$tmp/home/.muttrc"
  run "$ed rc-fallback ok" "$editor" "$root/test/rc-fallback.vim" \
    HOME="$tmp/home" PATH="$nomutt" MQ_MODE=ok MQ_EXPECT='mq-query --flag %s'
  printf 'set query_command="no-such-query %%s"\n' > "$tmp/home/.muttrc"
  run "$ed rc-fallback bad" "$editor" "$root/test/rc-fallback.vim" \
    HOME="$tmp/home" PATH="$nomutt" MQ_MODE=bad MQ_EXPECT='no-such-query %s'
done
exit $status
