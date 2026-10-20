# Guardrails

Three recipes. Pick one, configure it against your own plan, and prove it binds
by capturing a block.

They are three different classes of boundary:

| Recipe | Class | Enforced by | Works with |
|---|---|---|---|
| A | Permission boundary | the agent tool's permission layer | Claude Code (many tools have an equivalent) |
| B | Hook gate | a script the tool runs before each edit | Claude Code (many tools have an equivalent) |
| C | Filesystem lockdown | the operating system | any tool, any editor, any script |

Recipes A and B are written out for Claude Code. If you use a different tool, its
equivalent of A or B is fine. You can ask your agent to produce them.
The captured block is what counts.

All three ship with an obvious placeholder, `MODULE-YOU-ARE-NOT-TOUCHING`. Replace
it with the modules your plan puts out of scope. Until you do, recipe B blocks
every file-editing call and says it is unconfigured, and recipe C refuses to run
at all.

---

## Recipe A: permission boundary

Deny the agent write access to the modules your plan puts out of scope, plus the
commands you never want it running on your behalf.

**Configure.** Create `.claude/settings.json` at the repository root and copy the
`permissions` block out of `settings-snippet.json` in this directory. Copy it
rather than retyping it, then replace each `MODULE-YOU-ARE-NOT-TOUCHING` with a
real module, one rule per module (add lines if you have more). As shipped it
denies seven path patterns and three commands (`git push`, `rm`, and `sudo`).

**Check that it was picked up.** Settings reload when you save the file, so there
is nothing to restart. A file with broken JSON is skipped. Mid-session that is
silent, but the next session start shows a Settings Error. A stray trailing comma
from hand copying is the usual cause. Run `/status` and read the **Setting
sources** line. If your file is not listed there, the rules are not in effect.

**The conventions files are denied on purpose.** `AGENTS.md`, `CLAUDE.md`, and
`CHANGE-REQUEST.md` are in the shipped list because the agent's work is judged
against them. The change request also asks for a documentation update, so you
will be blocked here at some point. That is a human-takeover moment. Make those
edits yourself, or narrow the deny list when you get there and say in your plan
that you did.

Three details decide whether this works:

- Write the rules on **`Edit`**. Path rules are only consulted for `Edit` and
  `Read`. An `Edit` rule covers every built-in file-editing tool, including
  `Write` and `NotebookEdit`. A `Write(some/path)` rule is never consulted.
  Recent versions warn about it at startup, but older ones stay silent, so you
  get a config that looks right and blocks nothing. A bare `Write` with no path,
  denying the tool outright, is enforced.
- The **single leading slash** anchors to the directory the session was started
  in, which is the repository root when you start the agent there (`SETUP.md`
  step 6). `Edit(billing/**)` without the slash is relative to the working
  directory, and `Edit(//billing/**)` means the filesystem root.
- `Bash(git push:*)` prefix-matches, so it also covers `git push --force`. Write
  `Bash(rm *)` rather than `Bash(rm -rf *)`, which misses `rm -fr` and
  `rm -r -f`.

**What it cannot catch.** An edit inside an allowed
path that changes out-of-scope behavior gets through. It also only covers the
built-in file tools and the file commands Claude Code recognizes inside Bash. A
`cp` or `mv` onto a denied file, a path held in a shell variable, or a script the
agent writes and runs can all write a denied file.

---

## Recipe B: hook gate

Run a script before every file edit and refuse the ones that target protected
paths. `protect.py` is provided. You set its list.

**Configure.**

1. Edit `PROTECTED_PATHS` at the top of `guardrails/protect.py`, replacing
   `MODULE-YOU-ARE-NOT-TOUCHING/` with the modules your plan puts out of scope.
   `PROTECTED_FILES` already covers the conventions files.
   As shipped, before you edit that list, the script blocks every file-editing
   call and says it is not configured. A guardrail that is
   protecting nothing should say so rather than let work through.
2. Check the script by itself, with no agent involved:

   ```
   python3 guardrails/protect.py --self-test
   ```

   ```
   echo '{"tool_name":"Edit","tool_input":{"file_path":"billing/Money.java"}}' \
       | python3 guardrails/protect.py ; echo "exit $?"
   ```

   Once your list is set, a blocked path prints the reason and exits 2, and an
   in-bounds path prints nothing and exits 0. Check one path from every module on
   your list, since a missing comma between two entries joins them into one path
   and silently protects neither. The self-test uses a synthetic list of its own,
   so it checks the matching rules rather than your list.
3. Copy the `hooks` block out of `settings-snippet.json` into
   `.claude/settings.json`. Hooks reload on save, so there is nothing to restart,
   but the same broken-JSON trap applies. Run `/status` and confirm your settings
   file appears on the **Setting sources** line.

**The conventions files are protected on purpose.** `PROTECTED_FILES` ships with
`AGENTS.md`, `CLAUDE.md`, and `CHANGE-REQUEST.md` in it, the same three recipe A
denies, for the same reason. The change request asks for a documentation update,
so you will be blocked here. Make those edits yourself, or narrow the list when you
get there and say in your plan that you did.

Details that decide whether this works:

- **Exit 2 blocks. Exit 1 does not.** A hook that exits 1 is treated as broken
  and the edit proceeds. That is why the snippet does not call the script
  directly. It calls it through a shell wrapper:

  ```
  sh -c 'python3 "$CLAUDE_PROJECT_DIR/guardrails/protect.py"; [ $? -eq 0 ] || exit 2'
  ```

  The wrapper turns every non-zero exit into a 2. Without it, a typo in
  `PROTECTED_PATHS` is a syntax error, Python exits 1 before a line of the script
  runs, and your edit gets through a guardrail you believe is on. The script
  cannot catch that itself, because it never starts. Inside that wrapper the
  script fails closed. An unreadable payload, an edit whose target it cannot work
  out, an unconfigured list, and an exception at run time all block.
- Whatever the hook prints to **stderr** is what the agent is told. That is why the
  refusal names the path and the pattern.
- `$CLAUDE_PROJECT_DIR` is set for the hook command and is what `protect.py`
  measures its paths against. Keep it quoted, since a path with a space in it
  will otherwise split.
- A `matcher` of plain names joined by `|` is an exact list, which is what you
  want here. Use only letters, digits, `_`, `-`, spaces, commas, and `|`. Any
  other character turns it into an unanchored regular expression, so `.*Edit`
  would match more than you meant.

**What it cannot catch.** The matcher covers file-editing tools, so it never fires
on a Bash call. `sed -i`, `cp`, or a Python one-liner writes the protected file
without the hook seeing it. Like recipe A, it also has nothing to say about an
in-bounds edit that changes out-of-scope behavior.

---

## Recipe C: filesystem lockdown

Make the out-of-scope sources read-only. The operating system enforces it, so it
holds against any tool or subprocess that does not first change the file
permissions back.

**Configure.**

1. Edit `guardrails/protected-trees.txt`, replacing the placeholder with your
   out-of-scope modules.
2. Check the list, then lock:

   ```
   guardrails/lockdown.sh --list
   guardrails/lockdown.sh
   ```

3. Unlock when the task is done:

   ```
   guardrails/unlock.sh
   ```

Three things to know:

- It locks each module's `src/` and its `pom.xml`, so `target/` stays writable.
  Every per-module gate and the full `mvn -B test` run green while the lock is
  on. A build failure while locked has a cause other than the lock.
- It is shaped for the Java modules, which is what `src/` and `pom.xml` mean. The
  Python `analytics` package has neither, so `lockdown.sh` skips it, says so, and
  exits non-zero. If your plan puts `analytics` out of scope, protect it with
  recipe A or recipe B instead, which work on any path.
- Pair it with a diff audit, because nothing here tells you what the agent did
  inside the trees you left open:

  ```
  git add -N . && git diff --stat
  ```

  Plain `git diff --stat` leaves out new files, which is why `git add -N .` comes
  first. Locking and unlocking does not show up in that diff. Git records only
  whether a file is executable, and neither script touches that bit.

**What it cannot catch.** The agent can still
propose bad code inside the trees you left open, and the lock says nothing about
whether the change was a good idea. You
own these files, so `chmod -R u+w` undoes the lock, and an agent with shell
access can run that. Treat it as a stop on accidental writes.

---

## Demonstration protocol

The same for all three recipes. A configuration you never triggered is not
evidence.

1. Configure the recipe against your own out-of-scope list.
2. Put the agent in Manual mode (start it with `claude --permission-mode manual`,
   or press Shift+Tab to cycle to Manual). Current Claude Code starts in auto
   mode, where the agent often makes small edits through Bash (`cp`, `sed`, `mv`).
   Recipes A and B do not see those, so you may get no block to capture.
3. Ask the agent, on purpose, to do something out of bounds. Be specific, for
   example "use your Edit tool to add a comment at the top of
   `billing/src/main/java/.../Money.java`".
4. **Capture the block.** Save one excerpt of the agent's own turn showing what
   you asked for, its tool call, and the block the guardrail returned.
   A bare terminal paste with no agent turn around it does not show the boundary
   binding, because it does not show anything trying to cross it.
5. Confirm the file is unchanged.
6. Write one line saying what this boundary cannot catch.

## Limits

Recipe A's deny rules are applied by the tool itself, outside anything the agent
runs, and the shipped list keeps the file tools out of `.claude/` and
`guardrails/`. It is not airtight. Settings reload on save, and a shell command
can rewrite the settings file, so no recipe here survives an agent that has been
told to reconfigure its own boundary.

A rewritten settings file or guardrail script shows up in the diff. A `chmod`
does not, which is one more reason to treat recipe C as a stop on accidents.

None of them replaces checking the diff's file list against your task's scope.
