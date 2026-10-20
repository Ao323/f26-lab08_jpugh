#!/usr/bin/env bash
#
# Makes the sources listed in protected-trees.txt read-only.
#
# This is the only guardrail in the menu that works with any tool. The agent
# cannot write a file the operating system will not let it write.
#
# For each listed module it locks `src/` and `pom.xml`, and nothing else. The
# module directory and its `target/` stay writable, so every gate and the whole
# root build still run green while the lock is on. Run unlock.sh when the task is
# done.
#
# Usage, from anywhere:
#     guardrails/lockdown.sh
#     guardrails/lockdown.sh --list      show what would be locked and stop
#
# Works on macOS and Linux. It needs no root, because it only touches files you
# already own.

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${script_dir}/.." && pwd)"
tree_list="${script_dir}/protected-trees.txt"
placeholder="MODULE-YOU-ARE-NOT-TOUCHING"

if [ ! -f "${tree_list}" ]; then
  echo "lockdown: no tree list at ${tree_list}" >&2
  exit 1
fi

trees=()
while IFS= read -r line; do
  trees+=("${line}")
done < <(sed -e 's/#.*$//' -e 's/[[:space:]]*$//' "${tree_list}" | grep -v '^$' || true)

if [ "${#trees[@]}" -eq 0 ]; then
  echo "lockdown: ${tree_list} lists no trees, so there is nothing to protect" >&2
  exit 1
fi

for tree in "${trees[@]}"; do
  if [ "${tree}" = "${placeholder}" ]; then
    echo "lockdown: ${tree_list} still holds the shipped placeholder ${placeholder}." >&2
    echo "lockdown: edit it to the modules your plan puts out of scope, then run again." >&2
    exit 1
  fi
done

# Refuses anything that could point outside the repository.
check_entry() {
  local tree="$1"
  case "${tree}" in
    /*)
      echo "lockdown: ${tree} is absolute, entries must be relative to the repository root" >&2
      return 1 ;;
    *..*)
      echo "lockdown: ${tree} contains .., which could point outside the repository" >&2
      return 1 ;;
  esac
  local resolved
  resolved="$(cd "${repo_root}/${tree}" 2>/dev/null && pwd -P || true)"
  if [ -z "${resolved}" ]; then
    echo "lockdown: ${tree} is not a directory under the repository root" >&2
    return 1
  fi
  case "${resolved}" in
    "$(cd "${repo_root}" && pwd -P)"/*) return 0 ;;
    *)
      echo "lockdown: ${tree} resolves to ${resolved}, which is outside the repository" >&2
      return 1 ;;
  esac
}

if [ "${1:-}" = "--list" ]; then
  echo "lockdown would make read-only, under ${repo_root}:"
  problems=0
  for tree in "${trees[@]}"; do
    if ! check_entry "${tree}" 2>/dev/null; then
      echo "  ${tree}   REJECTED, see the message below"
      check_entry "${tree}" >/dev/null || true
      problems=$((problems + 1))
    elif [ ! -d "${repo_root}/${tree}/src" ]; then
      echo "  ${tree}   REJECTED, no src directory to lock"
      problems=$((problems + 1))
    elif [ ! -f "${repo_root}/${tree}/pom.xml" ]; then
      echo "  ${tree}/src   (no pom.xml, only src will be locked)"
    else
      echo "  ${tree}/src and ${tree}/pom.xml"
    fi
  done
  if [ "${problems}" -gt 0 ]; then
    echo
    echo "lockdown: ${problems} of these would be rejected. Fix ${tree_list} before locking." >&2
    exit 1
  fi
  exit 0
fi

locked=0
skipped=0
locked_trees=()
for tree in "${trees[@]}"; do
  if ! check_entry "${tree}"; then
    skipped=$((skipped + 1))
    continue
  fi
  target="${repo_root}/${tree}"
  if [ ! -d "${target}/src" ]; then
    echo "lockdown: ${tree} has no src directory, nothing to lock" >&2
    skipped=$((skipped + 1))
    continue
  fi
  chmod -R a-w "${target}/src"
  if [ -f "${target}/pom.xml" ]; then
    chmod a-w "${target}/pom.xml"
  fi
  echo "locked ${tree}/src and ${tree}/pom.xml"
  locked_trees+=("${tree}")
  locked=$((locked + 1))
done

if [ "${skipped}" -gt 0 ]; then
  echo >&2
  echo "lockdown: ${skipped} listed tree(s) were skipped and are NOT protected." >&2
  if [ "${locked}" -eq 0 ]; then
    echo "lockdown: nothing was locked. Fix ${tree_list} and run this again." >&2
  else
    echo "lockdown: what did get locked stays locked until you unlock it:" >&2
    for tree in "${locked_trees[@]}"; do
      echo "lockdown:   ${tree}" >&2
    done
    echo "lockdown: fix ${tree_list}, then run guardrails/unlock.sh and lock again." >&2
  fi
  exit 1
fi

if [ "${locked}" -eq 0 ]; then
  echo "lockdown: nothing was locked, check the paths in ${tree_list}" >&2
  exit 1
fi

echo
echo "${locked} tree(s) are now read-only. target/ stays writable, so the gates still run."
echo "Prove it binds: ask the agent to edit a file under one of them and capture what happens."
echo "Run guardrails/unlock.sh when you are done."

