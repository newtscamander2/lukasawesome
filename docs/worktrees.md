# University notes in git, one worktree per course

Your notes live in one private GitLab repository, `newtscamander/aarhusuni`, laid
out so that each course has its own working directory. This is what that means,
why it is arranged this way, and what to do when something looks wrong.

Set up (or restored on a new machine) with `make notes`.

---

## 1. What a worktree is

A normal git repository has **one** working directory. `git checkout` swaps its
contents: switch branch and the files under you change. That is fine for code,
and wrong for notes — you do not want the maths folder to vanish because you
last touched something else.

Worktrees let one repository have **several working directories at once, each on
its own branch**. Nothing is duplicated: there is one history, shared by all of
them, so fetching in one is fetching in all of them. Git refuses to check out
the same branch in two directories, so two worktrees can never fight.

For notes that means `~/aarhusuni/course/math` **is** the maths branch. You never
check out, never stash, never lose your place. Leaving class is closing a laptop.

```
~/aarhusuni/
  .bare/                     the history itself (a bare repository)
  .git                       one line: "gitdir: ./.bare"
  main/                      branch main — every course, merged
    0semester/testcourse/…
    0semester/math/…
  course/
    math/                    branch course/math — only maths is checked out here
      0semester/math/2026-09-01-induction/main.tex
    beregnelighed-og-logik/  branch course/beregnelighed-og-logik
  restore/                   appears only when you run gm --restore
```

`gm` is unchanged by any of this: it finds its bearings from the nearest
`<N>semester` directory, so inside a course worktree it behaves exactly as it
always has.

### What `course/` is

Nothing of yours is stored in it. A worktree's directory mirrors its branch
name, and the `/` in a branch name is a directory separator — so branch
`course/math` is checked out at `course/math`, and git makes the `course/`
folder to hold it. It contains no tracked files at all.

The prefix earns its keep three times over: `.githooks/pre-commit` derives the
allowed directory from it (`course/math` → `<N>semester/math/`), it keeps the
three kinds of branch apart (`main`, `course/*` your work, `wip/*` backups), and
it keeps the top of the repository readable.

Do not put anything directly in `course/` — like the top of the repository, it
sits outside every worktree, so git does not track it and the snapshot timer
does not back it up.

### Why "math" appears twice in the path

`~/aarhusuni/course/math/0semester/math/…` names two different things:

- **`course/math`** is the *worktree directory*, named after the branch. It is a
  checkout location, not part of your notes.
- **`0semester/math`** is the *course*, and it is what actually gets committed.
  It has to look identical here and in `main/` — that is precisely what makes
  merging a course into `main` a decision git can make without you.

So the repetition cannot be removed without giving up the property that makes
the merges safe. In practice you rarely see it: `class math` puts you straight
into the second one.

### Each course worktree shows only its own course

A worktree normally checks out the *whole* branch, which would leave a stale copy
of every other course inside a directory called `math`. `gm --class` therefore
sets a **sparse-checkout** on each course worktree, so it holds only
`<N>semester/<that course>/` — plus `.gitignore`, `README.md` and `.githooks/`,
which git needs at the top of the tree.

The other courses are hidden, not gone: they are still in the branch, still in
`main/`, and still in every snapshot. `git add -A` honours the sparse rules, so
neither a commit nor a backup ever records them as deleted. It is refreshed every
time you run `class`, so a new semester is let through automatically.

One pleasant side effect: git now refuses to even *stage* a file belonging to
another course from here, before the commit hook gets a chance to.

---

## 2. The whole thing in one lecture

```bash
class math                              # cd's you into the course, making it
                                        # the first time you ever type it
gm --create-lecture "Induction proofs"  # today's entry, from the goat template
cd 2026-09-01-induction-proofs
nvim main.tex                           # …the lecture happens…
latexmk -pdf main.tex

gm --wrap-up -m "induction proofs"      # commit, push, merge into main
```

If you never get to that last line — the lecture overruns, the battery dies —
your work is still on GitLab. See §4.

The rest:

| Command | What it does |
|---|---|
| `class` | list every course and how it is doing |
| `class math` | open a course (creates branch, worktree and directory as needed) |
| `class math --semester 3` | ...putting a *new* course in a named semester |
| `pending` (`gm --pending`) | **anything not safely on GitLab yet** |
| `gm --sync` | fetch and fast-forward everything — run it when you sit down |
| `gm --wrap-up [-m MSG]` | commit, push, merge this course into main |
| `gm --close <course>` | done with it: remove the directory, keep everything else |
| `gm --save` | snapshot now (the timer already does this every 5 minutes) |
| `gm --restore math` | recover a snapshot, on any machine |
| `gm --nest --project NAME` | make this entry its own project, to share it |

`class` and `pending` are shell functions (`bash/.bashrc`) rather than programs,
because only a shell function can change the directory you are standing in.

### Which semester a new course goes in

The first time you open a course, `class` asks — it does not guess:

```
:: danish is new. Semesters here: 2semester, 3semester
?  which semester does danish belong to? [3semester]
```

Enter accepts the newest one; `1` or `1semester` both work. Skip the question
with `class danish --semester 3`. Reopening an existing course never asks: it
takes you to wherever that course already lives, and says so rather than
quietly making a second copy if `--semester` disagrees.

Run without a terminal (a script, the timer), it takes the newest semester
silently, since there is nobody to ask.

### The same course in two semesters

Allowed. A subject taken again, or continued, can live in both — the commit hook
permits `<any N>semester/<course>/`, so nothing objects.

What there is only one of is the **branch and the worktree**: the course *name*
maps to `course/math`, so both semesters' copies sit side by side in that one
directory, on one branch. You cannot work on them as two independent lines of
history, which is exactly what you want — they are one subject.

`class math` then opens the newest and says so; `class math --semester 1` opens
the one you name.

---

## 3. Why you cannot get a merge conflict

Not "unlikely" — there is no path to one, by construction.

**Work in a course's directory may only touch that course.** In
`~/aarhusuni/course/math` you can only change files under `<N>semester/math/`.
Two courses therefore never edit the same file, and every merge is decided by git
without asking you anything. This is enforced by `.githooks/pre-commit`, which is
committed *inside* the notes repository, so every machine that clones gets it.

The rule follows the **directory**, not the branch. That matters: you can branch
and experiment inside a course worktree as freely as you like — `git switch -c
feature/whatever`, try something, switch back — and the guardrail still applies.
Keying it on the branch name would have meant the protection silently switched
off the moment you left `course/math`, which is exactly when a stray commit is
most likely.

**`main` is only ever written by merging.** You never edit it by hand, so it
cannot diverge in a way that needs resolving.

**A course branch is always an ancestor of `main`.** `gm --wrap-up` merges into
`main` and then fast-forwards the course branch back up to it. So the next merge
is trivially clean too, and every course worktree holds the whole current tree.

**Divergence is refused, not resolved.** If the same course was edited on two
machines, `gm --sync` stops and prints both sides instead of starting a merge you
did not ask for. Nothing is changed until you decide.

If you ever genuinely need a commit spanning two courses:

```bash
GOAT_ANY=1 git commit -m "…"
```

The hook also refuses two other things: a file over 20 MB (history is forever — a
stray lecture recording stays in every future clone even after you delete it),
and an accidental **gitlink**, which is the trap in §6.

---

## 4. The five-minute safety net

`goat-autosave.timer` runs every five minutes. For each worktree it takes
everything in the directory — committed or not — and pushes it to a branch called
`wip/<this machine>/<branch>`.

It does this with a throwaway index and `git commit-tree`, writing the commit
object straight into the store. It never runs `git add`, `git commit` or
`git checkout` against your real state. **Your index, your working tree and your
branches are never touched**, and your history stays exactly as clean as you make
it. Nothing ever merges from a `wip/` branch.

So, laptop stolen between lectures:

```bash
# on any other computer
make notes            # clones everything back
gm --restore math     # the snapshot, including what was never committed
```

It lands in `~/aarhusuni/restore/course-math/` as a detached worktree, so it can
never be mistaken for live work. Take what you need and
`git -C ~/aarhusuni worktree remove restore/course-math`.

Snapshot branches are named per machine, so a laptop and a desktop can never
overwrite each other's.

**Two things this does not cover, both on purpose:**

- **Ignored files are not backed up.** `.gitignore` is a list of things that are
  derived — `latex_debug_files/`, `.aux`, `.log`. They are rebuilt by `latexmk`,
  not recovered. Anything you would be sad to lose must not be ignored.
  **PDFs are deliberately not ignored**: "what exactly did I hand in?" has one
  correct answer, and it is not "whatever recompiling produces today". The cost
  is that rebuilding a document shows it as changed even when the `.tex` did not
  move.
- **The push needs a key the timer can use.** That is what the deploy key is
  for (below). Without it, a snapshot is still written locally and only the push
  fails; `gm --pending` says so in yellow.

### The unattended key

A timer that runs while nobody is at the keyboard cannot answer a passphrase
prompt. `make notes` therefore creates a **second** key with no passphrase,
`~/.ssh/id_ed25519_aarhusuni`, and an ssh alias that offers only that key:

```
Host gitlab-aarhusuni      ->  gitlab.com, IdentityFile id_ed25519_aarhusuni,
                               IdentitiesOnly yes
```

The notes remote uses `git@gitlab-aarhusuni:…`, so this key is used for the
notes and nothing else uses it. Register it on the project — *Settings →
Repository → Deploy keys*, ticking **Grant write permissions** — not on your
account.

**What that scoping actually gives you.** The key is unencrypted on disk, so
what matters is how far it reaches. As a deploy key it reaches exactly one
project: lose the laptop and you revoke one key in one project's settings, and
`goat`, `cv`, `lukasawesome` and your GitLab account are untouched.

**What it does not give you, despite the name.** A write deploy key can push to
any branch its creator could — not only `wip/*`. GitLab has no branch-scoped
deploy keys on Free: protecting `main` against everyone would block your own
pushes too, and restricting by branch name needs push rules, which are paid.
So read it as *"full write access to the notes project, and nothing else"*.
If that is too much, the alternative is to have no unattended key at all and
`ssh-add` once per boot — snapshots then wait for you, and `gm --pending` tells
you when they are waiting.

`make check-system` reports whether the key exists and whether GitLab has it.

Check on it: `systemctl --user list-timers goat-autosave`, or
`journalctl --user -u goat-autosave -n 20`.

---

## 5. Sharing one lecture with a classmate

GitLab project membership is all-or-nothing. There is no per-folder or per-branch
read scope, on any tier — adding someone to `aarhusuni` shows them every note you
have ever taken. So sharing one homework means that homework has to be its own
project:

```bash
cd ~/aarhusuni/course/math/0semester/math/2026-09-01-uge3
gm --nest --project uge3-gruppe
```

That entry becomes its own git repository, in place, with its own GitLab project.
The notes repository stops tracking the directory and ignores it instead (in
`<semester>/<course>/.gitignore`, which is committed, so every machine agrees).
Then invite the classmate to `uge3-gruppe` alone — Reporter to read, Developer to
write.

One source of truth, nothing syncing between the two repositories, nothing to
merge. The entry stays exactly where it is in your tree, so `gm` and `latexmk`
carry on as normal.

It is recorded in `<semester>/<course>/.gm-nested`, which is how a fresh clone
knows to fetch it: `gm --nest restore`. (Per course, not one file at the top —
a single file at the root would be the one path two course branches could both
edit, and this layout has no other.)

---

## 6. A repository inside a repository, safely

The danger is not nesting. It is that git will happily record the inner
repository in the outer one as a **gitlink**: a bare 40-character hash with no
record of where it came from. Clone the outer repository on another machine and
you get an empty directory that nothing can fill.

`.githooks/pre-commit` refuses that commit and tells you what to do instead.
Real submodules — the ones listed in `.gitmodules` — are still allowed, so a
deliberate one is never blocked.

The safe way is always `gm --nest`: it takes the directory out of the parent's
tracking, ignores it, and registers it so it can be cloned back.

---

## 6b. Finishing a course

At the end of a semester you have no use for eight working directories, and
every one of them shows up in `gm` and gets walked by the snapshot timer every
five minutes.

```bash
gm --close math
```

Only the **directory** goes. The branch stays, every commit stays in `.bare/`
and on GitLab, `main/` still holds all the notes, and `class math` builds the
directory again in a second with everything in it. `gm --see-all` lists the
courses in this state.

It refuses while anything is uncommitted, unpushed or unmerged — "I am finished
with this" and "this is safely on GitLab" have to be the same statement. That
refusal is the only thing standing between you and
`git worktree remove --force`, so do not reach past it.

## 6c. If wrap-up stops halfway

It will, eventually — eduroam drops, or the laptop sleeps mid-push.
`gm --wrap-up` is built to be run again: every step checks whether it is already
done, and no step depends on an earlier one having run in the same invocation.
When it stops it tells you exactly what is left:

```
  ! not finished. Still to do:
     push main to GitLab
:: nothing was lost -- run gm --wrap-up again when it can reach GitLab
```

Run the same command again on a working network. There is no separate resume
command and no state file to clean up: the repository itself is the record.

## 7. When something looks wrong

**"I don't know what state I'm in."** `pending`. It is the whole answer: every
worktree, every nested repository, everything uncommitted or unpushed, and when
the last snapshot went out.

**A commit was refused.** Read the message — it names the files that were outside
the branch's course and gives you the `git restore --staged` line. Nothing was
changed; your work is exactly where it was.

**`gm --sync` says a course has diverged.** The same course was committed on two
machines. It prints both commands: `log --oneline origin/<branch>..HEAD` for
yours, `HEAD..origin/<branch>` for the other machine's. Nothing has been changed.
Usually the answer is to merge them by hand once, in that course's worktree.

**A worktree directory is gone.** `git -C ~/aarhusuni worktree prune`, then
`class <name>` to make it again. The branch — and every commit on it — was never
in the directory; it is in `.bare/`.

**Snapshots stopped.** `systemctl --user status goat-autosave.timer`. Almost
always the SSH agent: `ssh-add -l`. The local snapshots are still being written
either way.

**A course branch is behind main.** Harmless, and `gm --sync` or the next
`gm --wrap-up` fixes it. Course branches only carry their own course's work; the
merged whole always lives in `main/`.

**"You are in a sparse checkout with N% of tracked files present."** Expected —
see §1. The missing files are the other courses. `main/` has them all, and
`git sparse-checkout disable` in that worktree brings them back if you ever want
them; running `class <name>` again re-applies it.

**A file refuses to be staged in a course worktree.** It belongs to another
course, so it is outside this worktree's sparse checkout. Commit it from its own
course (`class <that course>`) — which is the point.

---

## 8. Where everything is

| | |
|---|---|
| the notes | `~/aarhusuni` |
| the tool | `~/lukasawesome/bin/goat-manager` (`gm`) |
| `class`, `pending` | `~/lukasawesome/bash/.bashrc` |
| setup / restore | `~/lukasawesome/scripts/notes.sh` (`make notes`) |
| the hook, as shipped | `~/lukasawesome/scripts/notes-hooks/pre-commit` |
| the hook, in use | `~/aarhusuni/main/.githooks/pre-commit` (committed, so it travels) |
| the timer | `~/lukasawesome/notes/.config/systemd/user/goat-autosave.{service,timer}` |

Everything `gm` knows it works out from the directory layout. There is no config
file to keep in sync — only optional environment variables (`GOAT_NOTES`,
`GOAT_AUTHOR`, `GOAT_STUDENT_ID`, `GOAT_LANG`, `GOAT_STYLE`).
