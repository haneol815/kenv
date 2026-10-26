#!/usr/bin/env bash
# End-to-end tests for bin/kenv + kenv.sh (bash). Usage: tests/test_linux.sh
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export KENV_HOME; KENV_HOME="$(mktemp -d)"; export XDG_DATA_HOME="$KENV_HOME/xdg"
# shellcheck source=/dev/null
source "$ROOT/kenv.sh"
PASS=0; FAIL=0; W="$KENV_HOME/work"; mkdir -p "$W"
ok(){ if eval "$2" >"$W/out" 2>&1; then PASS=$((PASS+1)); echo "PASS $1"; else FAIL=$((FAIL+1)); echo "FAIL $1"; sed 's/^/   | /' "$W/out" | tail -15; fi; }
no(){ if eval "$2" >"$W/out" 2>&1; then FAIL=$((FAIL+1)); echo "FAIL $1 (expected failure)"; else PASS=$((PASS+1)); echo "PASS $1"; fi; }

ok "help"                     "kenv help | grep >/dev/null create"
no "unknown command"          "kenv bogus"
no "create without name"      "kenv create"
no "bad name ../x"            "kenv create ../x"
no "bad name with space"      "kenv create 'a b'"
no "bad name -x"              "kenv create -- -x"
ok "create a (3.11 + six)"    "kenv create a --python 3.11 six"
no "duplicate create"         "kenv create a --python 3.11"
no "create bad pkg rolls back" "kenv create bad --python 3.11 this-package-does-not-exist-kenv-zzz"
ok "rollback removed dir"     "test ! -e $KENV_HOME/envs/bad"
ok "create b (3.12 vuln pin)" "kenv create b --python 3.12 urllib3==1.26.5"
ok "list shows both"          "kenv list | grep >/dev/null ' a ' && kenv list | grep >/dev/null ' b '"
no "install no target"        "kenv install six"
no "install nonexistent env"  "kenv install -n nope six"
no "install no packages"      "kenv install -n a"
ok "activate a"               "kenv activate a && [[ \$VIRTUAL_ENV == $KENV_HOME/envs/a ]]"
kenv activate a
ok "python from env"          "[[ \$(command -v python) == $KENV_HOME/envs/a/bin/python ]]"
ok "install into active"      "kenv install -q packaging && python -c 'import packaging'"
ok "list marks active"        "kenv list | grep >/dev/null '^\*a'"
no "remove active env"        "kenv remove a"
ok "activate b while active"  "kenv activate b && [[ \$VIRTUAL_ENV == $KENV_HOME/envs/b ]] && kenv activate a"
kenv deactivate
ok "deactivated"              "[[ -z \${VIRTUAL_ENV:-} ]]"
no "deactivate when inactive" "kenv deactivate"
ok "export txt"               "kenv export -n a -o $W/a.txt && grep -q '^six==' $W/a.txt && grep -q '^# python: 3.11' $W/a.txt"
ok "export lock"              "kenv export -n a -o $W/a.lock --lock && grep -q sha256 $W/a.lock"
no "import missing file"      "kenv import x $W/nope.txt"
ok "import txt"               "kenv import a2 $W/a.txt && diff <(kenv freeze -n a) <(kenv freeze -n a2)"
ok "import lock"              "kenv import a3 $W/a.lock && diff <(kenv freeze -n a) <(kenv freeze -n a3)"
ok "import keeps python ver"  "kenv list | grep ' a3 ' | grep >/dev/null ' 3.11'"
ok "clone"                    "kenv clone b b2 && diff <(kenv freeze -n b) <(kenv freeze -n b2)"
no "clone missing src"        "kenv clone nope c"
no "clone onto existing"      "kenv clone a b"
ok "kernel"                   "kenv kernel -n a && test -f $XDG_DATA_HOME/jupyter/kernels/kenv-a/kernel.json"
no "audit vulnerable -> !=0"  "kenv audit -n b"
ok "audit clean -> 0"         "kenv audit -n a"
ok "remove + kernel cleanup"  "kenv remove a && test ! -e $KENV_HOME/envs/a && test ! -e $XDG_DATA_HOME/jupyter/kernels/kenv-a"
no "remove nonexistent"       "kenv remove a"
for e in a2 a3 b b2; do kenv remove "$e" >/dev/null; done
ok "list empty"               "[[ \$(kenv list | wc -l) == 1 ]]"
rm -rf "$KENV_HOME"
echo "== $PASS passed, $FAIL failed"; [[ $FAIL == 0 ]]
