#!/usr/bin/env bash
#
# Puts write permission back on the sources listed in protected-trees.txt.
#
# Mirrors lockdown.sh. It puts write permission back on `src/` and `pom.xml` for
# each listed module, for the owner and the group. It does not restore the exact
# modes the files had before the lock, and it does not need to. Git records only
# whether a file is executable, and neither script touches that bit, so a lock
# and unlock cycle leaves nothing in your diff.
#
# Run this when the task is finished, before you hand anything in. Nothing here
# needs to run before a build. lockdown.sh leaves target/ writable on purpose.
#
# Usage, from anywhere:
#     guardrails/unlock.sh

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${script_dir}/.." && pwd)"
tree_list="${script_dir}/protected-trees.txt"

if [ ! -f "${tree_list}" ]; then
  echo "unlock: no tree list at ${tree_list}" >&2
  exit 1
fi

trees=()
while IFS= read -r line; do
  trees+=("${line}")
done < <(sed -e 's/#.*$//' -e 's/[[:space:]]*$//' "${tree_list}" | grep -v '^$' || true)

if [ "${#trees[@]}" -eq 0 ]; then
  echo "unlock: ${tree_list} lists no trees, so there is nothing to unlock" >&2
  exit 1
fi

unlocked=0
skipped=0
for tree in "${trees[@]}"; do
  target="${repo_root}/${tree}"
  if [ ! -d "${target}/src" ]; then
    echo "unlock: skipping ${tree} (no src directory under the repository root)" >&2
    skipped=$((skipped + 1))
    continue
  fi
  chmod -R ug+w "${target}/src"
  if [ -f "${target}/pom.xml" ]; then
    chmod ug+w "${target}/pom.xml"
  fi
  echo "unlocked ${tree}/src and ${tree}/pom.xml"
  unlocked=$((unlocked + 1))
done

echo
echo "${unlocked} tree(s) are writable again."

if [ "${skipped}" -gt 0 ]; then
  echo "unlock: ${skipped} listed tree(s) were skipped and may still be read-only." >&2
  exit 1
fi
