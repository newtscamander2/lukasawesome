#!/usr/bin/env bash
# Tests for goat-manager's git layer.
#
#   make test          run everything
#   bash tests/test_goat_manager.sh -v      show each command as it runs
#
# Everything happens in a throwaway directory under $TMPDIR with its own bare
# "remote" on disk: no network, no GitLab, and NOTHING is ever done to
# ~/aarhusuni. That is not politeness -- a test suite that can touch the real
# notes is a test suite you will be afraid to run, and one you are afraid to run
# is one you will not run.
#
# These exist because of a specific afternoon. Four bugs shipped in one session
# and every one was invisible until someone happened to try the exact thing:
#
#   * a guard meant for restore worktrees fired on a normal course
#   * .strip() ate porcelain's status column, shifting every path by one char
#   * PrivateTmp=yes in the unit stopped ssh working, so backups silently died
#   * a course branch, once switched, lost its commit guardrail entirely
#
# Each has a test below. Add one whenever something bites you.
set -uo pipefail

GM="${GM:-$HOME/.local/bin/goat-manager}"
HOOK="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/scripts/notes-hooks/pre-commit"
VERBOSE=0
[ "${1:-}" = "-v" ] && VERBOSE=1

if [ -t 1 ]; then
    G=$'\033[1;32m'; R=$'\033[1;31m'; Y=$'\033[1;33m'; D=$'\033[2m'; N=$'\033[0m'
else
    G=''; R=''; Y=''; D=''; N=''
fi

passed=0; failed=0; current=""
fail() { printf '%s  ✗%s %s\n     %s\n' "$R" "$N" "$current" "$*"; failed=$((failed+1)); }
pass() { printf '%s  ✓%s %s\n' "$G" "$N" "$current"; passed=$((passed+1)); }
it()   { current="$*"; }
run()  { [ "$VERBOSE" = 1 ] && printf '%s     $ %s%s\n' "$D" "$*" "$N"; "$@"; }

# --- assertions --------------------------------------------------------------
assert_ok()      { if "$@" >/dev/null 2>&1; then pass; else fail "expected success: $*"; fi; }
assert_fails()   { if "$@" >/dev/null 2>&1; then fail "expected failure: $*"; else pass; fi; }
assert_eq()      { if [ "$1" = "$2" ]; then pass; else fail "expected '$2', got '$1'"; fi; }
assert_has()     { if printf '%s' "$1" | grep -qF -- "$2"; then pass
                   else fail "expected output containing '$2', got: $1"; fi; }
assert_hasnt()   { if printf '%s' "$1" | grep -qF -- "$2"; then fail "did not expect '$2' in: $1"
                   else pass; fi; }
assert_file()    { if [ -e "$1" ]; then pass; else fail "missing: $1"; fi; }
assert_no_file() { if [ -e "$1" ]; then fail "should not exist: $1"; else pass; fi; }

# --- a complete notes repository, from nothing -------------------------------
# Mirrors what scripts/notes.sh builds, so the tests exercise the real layout:
# bare repo + .git pointer + main worktree + the tracked hook.
make_repo() {
    local root="$1"
    mkdir -p "$root"
    git init -q --bare --initial-branch=main "$root/.bare"
    printf 'gitdir: ./.bare\n' > "$root/.git"
    git -C "$root/.bare" remote add origin "$REMOTE"
    git -C "$root/.bare" config remote.origin.fetch "+refs/heads/*:refs/remotes/origin/*"
    git -C "$root/.bare" config core.hooksPath .githooks
    git -C "$root/.bare" config user.email t@example.com
    git -C "$root/.bare" config user.name "Test"
    git -C "$root" worktree add -q --orphan -b main "$root/main" 2>/dev/null

    mkdir -p "$root/main/.githooks"
    install -m 0755 "$HOOK" "$root/main/.githooks/pre-commit"
    printf 'latex_debug_files/\n*.aux\n*.log\n' > "$root/main/.gitignore"
    mkdir -p "$root/main/0semester/existing"
    printf 'old notes\n' > "$root/main/0semester/existing/notes.tex"
    git -C "$root/main" add -A
    git -C "$root/main" commit -q -m "notes: start"
    git -C "$root/main" push -q --set-upstream origin main
}

WORK="$(mktemp -d "${TMPDIR:-/tmp}/gm-tests-XXXXXX")"
REMOTE="$WORK/remote.git"
NOTES="$WORK/notes"
git init -q --bare "$REMOTE"
export GOAT_NOTES="$NOTES"
export GIT_AUTHOR_NAME="Test" GIT_AUTHOR_EMAIL="t@example.com"
export GIT_COMMITTER_NAME="Test" GIT_COMMITTER_EMAIL="t@example.com"
cleanup() { rm -rf "$WORK"; }
trap cleanup EXIT

# Refuse to run if anything points at the real notes: the whole safety argument
# above depends on this being true.
case "$NOTES" in
    "$HOME"/aarhusuni*) echo "refusing to test against the real notes" >&2; exit 1 ;;
esac

printf '%s:: goat-manager tests%s  %s(%s)%s\n' "$Y" "$N" "$D" "$WORK" "$N"
make_repo "$NOTES"
cd "$NOTES"

# --- the layout --------------------------------------------------------------
it "a fresh repo reports nothing pending"
assert_has "$("$GM" --pending 2>&1)" "nothing pending"

it "class creates a branch, a worktree and the course directory"
out="$("$GM" --class math --semester 1 -q 2>&1)"
assert_eq "$(printf '%s' "$out" | tail -1)" "$NOTES/course/math/1semester/math"

it "the course worktree exists"
assert_file "$NOTES/course/math/1semester/math"

it "class is idempotent -- opening twice does not make a second thing"
"$GM" --class math -q >/dev/null 2>&1
assert_eq "$(git -C "$NOTES" worktree list | grep -c 'course/math')" "1"

# --- reserved and mistaken names ---------------------------------------------
it "class main is refused (it would shadow the merged branch)"
assert_fails "$GM" --class main -q

it "a second positional argument is refused, not ignored"
assert_fails "$GM" --class math extra -q

it "class course-math suggests the real name"
assert_has "$("$GM" --class course-math -q 2>&1)" "class math"

# --- the guardrail -----------------------------------------------------------
it "a course worktree may commit inside its own course"
printf 'hello\n' > "$NOTES/course/math/1semester/math/a.tex"
git -C "$NOTES/course/math" add -A
assert_ok git -C "$NOTES/course/math" commit -q -m "maths work"

# Outside the course means outside <N>semester/<course>/ -- including the files
# at the top of the repository, which belong to main. Another COURSE's path
# cannot be used here: sparse-checkout refuses to stage it before the hook ever
# runs, so a test written that way would pass without testing anything.
# `git checkout -- <file>` restores from the INDEX, so after a staged edit it
# restores the edit. --staged --worktree throws both away, which is what these
# need: a leftover dirty file poisons every test after it.
undo_edit() { git -C "$NOTES/course/math" restore --staged --worktree "$1"; }

it "a course worktree may NOT commit a file outside its course"
printf '\n# stray edit\n' >> "$NOTES/course/math/.gitignore"
git -C "$NOTES/course/math" add .gitignore
assert_fails git -C "$NOTES/course/math" commit -q -m "should be refused"

it "GOAT_ANY=1 is the deliberate way past it"
assert_ok env GOAT_ANY=1 git -C "$NOTES/course/math" commit -q -m "deliberate"
git -C "$NOTES/course/math" reset -q --hard HEAD~1

# The guardrail must follow the DIRECTORY, not the branch -- otherwise switching
# branches silently turns it off, which is when a stray commit is most likely.
it "the guardrail still applies on a non-course branch in the same worktree"
git -C "$NOTES/course/math" switch -q -c feature/experiment
printf '\n# stray edit\n' >> "$NOTES/course/math/.gitignore"
git -C "$NOTES/course/math" add .gitignore
assert_fails git -C "$NOTES/course/math" commit -q -m "refused on a feature branch too"
undo_edit .gitignore
git -C "$NOTES/course/math" switch -q course/math

it "the worktree is clean again before the next tests"
assert_eq "$(git -C "$NOTES/course/math" status --porcelain | wc -l)" "0"

it "an embedded repository cannot be committed as a gitlink"
git init -q "$NOTES/course/math/1semester/math/nested"
printf 'x\n' > "$NOTES/course/math/1semester/math/nested/f.txt"
git -C "$NOTES/course/math/1semester/math/nested" add -A
git -C "$NOTES/course/math/1semester/math/nested" commit -q -m init
git -C "$NOTES/course/math" add -f 1semester/math/nested 2>/dev/null
assert_fails git -C "$NOTES/course/math" commit -q -m "gitlink"
git -C "$NOTES/course/math" reset -q
rm -rf "$NOTES/course/math/1semester/math/nested"

# --- counting -----------------------------------------------------------------
# `git status --porcelain` collapses an untracked directory into ONE line, so a
# new lecture of ten files read as "1 uncommitted". And git()'s .strip() used to
# eat the leading status column, shifting every path by a character.
it "a new entry of two files counts as one entry, not one file"
mkdir -p "$NOTES/course/math/1semester/math/2026-01-01-lecture"
printf 'a\n' > "$NOTES/course/math/1semester/math/2026-01-01-lecture/main.tex"
printf 'b\n' > "$NOTES/course/math/1semester/math/2026-01-01-lecture/.latexmkrc"
assert_has "$("$GM" --pending 2>&1)" "1 uncommitted entry"

it "the entry is named, and its path is not truncated"
out="$("$GM" --pending 2>&1)"
assert_has "$out" "2026-01-01-lecture"

# git status --porcelain puts two status columns before each path, and for an
# unstaged change the first is a space. gm's helper used to .strip() the output,
# eating that space and shifting every path one character left: 1semester/...
# was reported as semester/... A path that starts "semester/" is the tell.
it "a modified tracked file keeps its full path (the .strip() bug)"
printf 'more\n' >> "$NOTES/course/math/1semester/math/a.tex"
out="$("$GM" --pending 2>&1)"
assert_has "$out" "1semester/math/a.tex"

it "and no path has lost its leading character"
if printf '%s' "$out" | grep -qE '(^|[[:space:]])semester/'; then
    fail "a path lost its first character: $out"
else
    pass
fi

# --- snapshots ----------------------------------------------------------------
it "--save writes a wip branch for uncommitted work"
"$GM" --save -q >/dev/null 2>&1
host="$(uname -n | tr -c 'A-Za-z0-9._-' '-' | sed 's/-*$//')"
assert_ok git -C "$NOTES" rev-parse --verify --quiet "refs/heads/wip/${host}/course/math"

it "the snapshot never touches your index or working tree"
assert_eq "$(git -C "$NOTES/course/math" diff --cached --name-only | wc -l)" "0"

it "the snapshot contains the uncommitted work"
snap="$(git -C "$NOTES" for-each-ref --format='%(refname)' 'refs/heads/wip/**' | head -1)"
assert_has "$(git -C "$NOTES" ls-tree -r --name-only "$snap")" "2026-01-01-lecture/main.tex"

it "--restore checks a snapshot out as restore-<course>"
"$GM" --restore math >/dev/null 2>&1
assert_file "$NOTES/restore-math"

it "a restore is not offered as a course"
assert_hasnt "$("$GM" --classes -q 2>&1)" "restore-math"

it "class refuses to treat a restore as a course"
assert_fails "$GM" --class restore-math -q

it "gm survives a worktree deleted with rm -rf"
rm -rf "$NOTES/restore-math"
assert_ok "$GM" --pending

it "and prunes the stale registration itself"
assert_hasnt "$(git -C "$NOTES" worktree list 2>&1)" "restore-math"

# --- wrap-up ------------------------------------------------------------------
it "--wrap-up commits, pushes and merges into main"
( cd "$NOTES/course/math" && "$GM" --wrap-up -m "week one" ) >/dev/null 2>&1
assert_has "$(git -C "$NOTES/main" log --oneline)" "merge math"

it "main now holds the course's work"
assert_file "$NOTES/main/1semester/math/2026-01-01-lecture/main.tex"

it "the course branch is an ancestor of main afterwards"
assert_ok git -C "$NOTES/course/math" merge-base --is-ancestor HEAD main

it "the course reports clean once merged"
assert_has "$("$GM" --pending 2>&1)" "nothing pending"

# Re-running must be a no-op, not an error: that is what makes it safe to run
# again after the network drops halfway through.
it "--wrap-up is safe to run again with nothing to do"
assert_ok env -C "$NOTES/course/math" "$GM" --wrap-up -m "again"

it "an interrupted wrap-up finishes on the second run"
printf 'later\n' > "$NOTES/course/math/1semester/math/late.tex"
( cd "$NOTES/course/math" && "$GM" --wrap-up -m "half" ) >/dev/null 2>&1
git -C "$NOTES/main" push -q origin main 2>/dev/null
git -C "$NOTES" update-ref -d refs/remotes/origin/main 2>/dev/null
( cd "$NOTES/course/math" && "$GM" --wrap-up -m "finish" ) >/dev/null 2>&1
assert_ok git -C "$NOTES/main" merge-base --is-ancestor HEAD origin/main

# --- close --------------------------------------------------------------------
it "--close refuses while work is uncommitted"
printf 'unsaved\n' > "$NOTES/course/math/1semester/math/draft.tex"
assert_fails "$GM" --close math

it "--close works once everything is merged and pushed"
rm "$NOTES/course/math/1semester/math/draft.tex"
assert_ok "$GM" --close math

it "closing removes the directory"
assert_no_file "$NOTES/course/math"

it "but keeps the branch and every commit"
assert_ok git -C "$NOTES" rev-parse --verify --quiet course/math

it "a closed course still shows under --see-all"
assert_has "$("$GM" --see-all 2>&1)" "math"

it "class brings it back with its notes intact"
"$GM" --class math -q >/dev/null 2>&1
assert_file "$NOTES/course/math/1semester/math/2026-01-01-lecture/main.tex"

# --- navigation ---------------------------------------------------------------
it "--root prints the top of the repository"
assert_eq "$("$GM" --root -q 2>&1)" "$NOTES"

it "--root works from deep inside an entry"
assert_eq "$(cd "$NOTES/course/math/1semester/math" && "$GM" --root -q 2>&1)" "$NOTES"

it "--root explains a course name instead of failing obscurely"
assert_has "$(cd "$NOTES" && "$GM" --root math 2>&1)" "class math"

it "--root main resolves"
assert_eq "$("$GM" --root main -q 2>&1)" "$NOTES/main"

# --- the tests' own promise ----------------------------------------------------
it "nothing here touched the real notes"
assert_hasnt "$WORK" "$HOME/aarhusuni"

printf '\n'
if [ "$failed" -eq 0 ]; then
    printf '%s ok%s %d passed\n' "$G" "$N" "$passed"
    exit 0
fi
printf '%s  x%s %d failed, %d passed\n' "$R" "$N" "$failed" "$passed"
exit 1
