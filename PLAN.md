# PLAN.md

One section per milestone. Fill them in order, with the plan before you run
anything, the guardrail before you run a task, and the run after.

Keep it short and specific. Point at modules, gates, and file paths.

---

## Milestone 1: The plan

Turn `CHANGE-REQUEST.md` into three or four agent-sized tasks in the
Supervision Plan format. Every task carries a verification checkpoint, and the
section ends with an out-of-scope list.

**The tasks.** Three or four of them in dependency order. A task is
agent-sized when one agent run can finish it and one gate can tell you whether
it did. For each one, give:

- what behavior it delivers (not "edit module X"), which modules it touches,
  and what it depends on
- its checkpoint, meaning the gate command you run and the observable result
  that would convince you the task is done ("Run the tests" is not a
  checkpoint)
- one specific way the task could go wrong and still leave the gate green

**AGENTS.md rules 3 and 4.** One line: which of your checkpoints catches an
agent that breaks rule 3 (the conflict predicate) or rule 4 (waitlist writes).

**Out of scope, with reasons.** Which modules you are not touching and why. A
reason is a clause in the change request or a rule in AGENTS.md, not "it seemed
unrelated".

---

## Milestone 2: The guardrail

Pick one recipe from `guardrails/README.md`. Configure it, then prove it binds.

**The recipe.** Which one you picked, the exact paths or trees it covers, and
one line on what it cannot catch.

**The captured block.** Paste the excerpt of the agent's own turn showing what
you asked it to do, its tool call, and the block the guardrail returned. A bare
terminal paste with no agent turn around it does not show the boundary binding.

---

## Milestone 3: The run

Run exactly ONE task from your plan with the agent, under the guardrail, through
its gate. Any task whose dependencies are done qualifies, including the
smallest one.

**The takeover point.** Write this before you start the run. A concrete,
conditional statement of when you would stop the agent and write the code
yourself. "If something looks wrong" does not count. Name the trigger and name
what you would do.

**The evidence.** Name the task from Milestone 1. Paste the result line of its
gate command (run it without `-q` so the line is in the output) and the result
line of one `mvn -B clean test` run after the task was finished. The module
gate cannot see a cross-module compile break on a warm tree. A cold build can,
and so can CI.

**The diff.** The files the agent changed, and how each one maps to that task's
declared scope (plain `git diff` leaves out new files, but
`git add -N . && git diff --stat` includes them). Note anything it touched that
you did not expect, including any shipped test. Then quote the one line you
read hardest and say what you were checking for.

**The refuter.** What you gave it and what you asked it to do (paste the
brief). Then the one finding you settled, and how (the new failing test with
its red run, or the evidence that dismissed it). If nothing it reported held
up, say how you checked its strongest claim.
