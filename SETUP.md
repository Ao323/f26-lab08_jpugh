# Setup

There are two toolchains, a JDK for the seven Maven modules and Python for the
analytics package. Neither one downloads a runtime dependency, so a first build only fetches
Maven's own plugins and JUnit.

## 1. Java and Maven

- A JDK, version 21 or newer. Check with `java --version`.
- Maven 3.8 or newer. Check with `mvn --version`.

From this directory:

```
mvn -B test
```

The whole build should finish well inside three minutes on a laptop, most of
which is Maven starting up rather than tests running.

## 2. Python

Python 3.11 or newer. Check with `python3 --version`.

pytest is the only thing to install. Put it in a virtual environment rather
than in your system Python:

```
python3 -m venv .venv
.venv/bin/pip install pytest
```

Then run it by path, from `analytics/`:

```
cd analytics
../.venv/bin/pytest
```

Or activate the environment once (`source .venv/bin/activate` on macOS and
Linux, `.venv\Scripts\activate` on Windows) and just run `pytest`. `.venv/` is
already in `.gitignore`.

The package itself uses only the standard library, so there is nothing to
install from `analytics/`.

## 3. The gates

The per-module gate runs in seconds, so you can run it after every change
rather than waiting on the whole build. Run these from this
directory.

| Gate | Command | Tests in this module |
|---|---|---|
| core-domain | `mvn -q -pl core-domain -am test` | 167 |
| storage | `mvn -q -pl storage -am test` | 63 |
| notifications | `mvn -q -pl notifications -am test` | 41 |
| accounts | `mvn -q -pl accounts -am test` | 19 |
| billing | `mvn -q -pl billing -am test` | 19 |
| http-api | `mvn -q -pl http-api -am test` | 78 |
| cli | `mvn -q -pl cli -am test` | 31 |
| analytics | `pytest` (from `analytics/`) | 137 |
| everything | `mvn -B test` | 418 |

These counts describe the starter as it ships. Your change should raise them. A
behavior change comes with a test, so a gate whose count has not moved needs a
second look. The 418 on the last row is the Java total. The 137 Python tests run
separately.

`-am` also builds and tests the modules the gate depends on, so the command's own
grand total is larger than the number above. `mvn -pl http-api -am test` runs
core-domain, storage, notifications, and accounts as well. The block for the
module you are working on is the one to read. When an `-am` gate fails, though,
read the FIRST failing module's block rather than your own. Maven stops at the
first failure, and everything after it is a consequence.

Green means the command prints nothing and exits zero. `-q` hides the successful
output. Drop `-q` when you need the module's
result line as evidence for someone else.

## 4. Running it

Compile once, then run either entry point straight off the class files:

```
mvn -q -DskipTests package
```

The HTTP API runs on port 8080. It prints a bearer token for each of the two seeded
accounts, one member and one administrator, so you can try both an owner-only
endpoint and an administrator reading someone else's booking:

```
java -cp "http-api/target/classes:core-domain/target/classes:storage/target/classes:notifications/target/classes:accounts/target/classes" \
  edu.cmu.cs214.campusreserve.http.CampusReserveServer 8080
```

The administrative commands. Each run builds a fresh in-memory platform, so
chain commands with a bare `+` when a later one needs to see what an earlier one
did:

```
java -cp "cli/target/classes:core-domain/target/classes:storage/target/classes:billing/target/classes" \
  edu.cmu.cs214.campusreserve.cli.CampusReserveCli help

java -cp "cli/target/classes:core-domain/target/classes:storage/target/classes:billing/target/classes" \
  edu.cmu.cs214.campusreserve.cli.CampusReserveCli seed + export-events --out events.jsonl
```

That second line writes `events.jsonl`, which the analytics package reads.

## 5. Editor

Any editor or IDE. VS Code, IntelliJ IDEA, and Eclipse all import a multi-module
Maven project from the root `pom.xml`. Point it at this directory. Opened on a
module directory, it will not resolve the sibling modules.

## 6. Your coding agent

Configure your coding agent with this directory as its working directory.
Claude Code picks up `CLAUDE.md`, which imports `AGENTS.md`. Most other tools
read `AGENTS.md` directly. Confirm the agent can see `AGENTS.md` before you start,
since your plan cites its conventions.

## 7. Before you hand anything in

Finish with one clean run of the whole build:

```
mvn -B clean test
```

Do this even when every gate was green a minute ago. Maven recompiles a
dependent module only in the invocation that rebuilt its dependency, so a warm
tree can hide a cross-module compile break that a cold build finds immediately.
CI builds cold, so it finds the same break.

## When something is wrong

- **A gate fails on a module you did not touch.** Read the failure before you do
  anything else, because there are two different causes. A compile error in a
  module you did not edit means your change crossed a module boundary and broke
  something downstream. Fix it, and think about whether your task's declared
  scope was right. Any other unexpected failure is usually a stale `target/`,
  and `mvn -B clean test` settles it.
- **Maven cannot resolve a sibling module.** You are probably running from inside
  a module directory. Run the gates from this directory.
- **A permissions error on a file the agent tried to edit under a locked `src/`.** That
  is the filesystem lockdown guardrail working, and it is what you want to
  capture as evidence. It does not affect the build. `lockdown.sh` leaves each
  module's `target/` writable on purpose, so every gate and the full build run
  green while the lock is on. If a build fails while you are locked, the lock is
  not the reason. Read the error. Run `guardrails/unlock.sh` once the task is
  done.
- **`pip install pytest` fails with `externally-managed-environment`.** Your
  Python is managed by the operating system and refuses to install into itself
  (PEP 668). Use the virtual environment in step 2. Do not reach for
  `--break-system-packages`.
- **`pip: command not found`.** Use `python3 -m pip` instead of `pip`, or use the
  virtual environment's own pip from step 2.
- **`pytest: command not found` after installing it.** The install went somewhere
  that is not on your PATH. Run it as `python3 -m pytest`, or by path from the
  virtual environment.
- **Anything else.** Ask your agent to help, or ask us if you're stuck!
