#!/usr/bin/env bash
# Checks pinned upstream versions and opens ONE PR with all newer versions.
# Usage: ./check-updates.sh [--dry-run]   (needs gh; in CI uses GITHUB_TOKEN)
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")"
DRY_RUN=0
[ "${1:-}" = "--dry-run" ] && DRY_RUN=1

newer() { # newer <current> <candidate>
  [ "$1" != "$2" ] && [ "$(printf '%s\n%s\n' "$1" "$2" | sort -V | tail -1)" = "$2" ]
}

# name | file | current | latest | sed expression template (@NEW@ is replaced)
current_mpv()     { sed -n 's/^MPV_VERSION="${MPV_VERSION:-\(.*\)}"/\1/p' download.sh; }
current_dovi()    { sed -n 's/^LIBDOVI_VERSION="\(.*\)"/\1/p' download.sh; }
current_placebo() { sed -n 's/^LIBPLACEBO_REF="v\(.*\)"/\1/p' download.sh; }
current_mvk()     { sed -n 's/^MOLTENVK_REF="${MOLTENVK_REF:-v\(.*\)}"/\1/p' build-macos.sh; }

latest_mpv()      { gh api repos/mpv-player/mpv/releases/latest -q .tag_name | sed 's/^v//'; }
latest_mvk()      { gh api repos/KhronosGroup/MoltenVK/releases/latest -q .tag_name | sed 's/^v//'; }
latest_placebo()  { gh api 'repos/haasn/libplacebo/tags?per_page=100' -q '.[].name' \
                      | grep -E '^v[0-9]+\.[0-9]+(\.[0-9]+)?$' | sed 's/^v//' | sort -V | tail -1; }
latest_dovi()     { gh api --paginate repos/quietvoid/dovi_tool/tags -q '.[].name' \
                      | grep -E '^libdovi-[0-9]+\.[0-9]+\.[0-9]+$' | sed 's/^libdovi-//' | sort -V | tail -1; }

apply() { # apply <component> <new>
  case "$1" in
    mpv)       sed -i.bak "s/^\(MPV_VERSION=\"\${MPV_VERSION:-\).*\(}\"\)/\1$2\2/" download.sh; rm -f download.sh.bak ;;
    libdovi)   sed -i.bak "s/^LIBDOVI_VERSION=.*/LIBDOVI_VERSION=\"$2\"/" download.sh; rm -f download.sh.bak ;;
    libplacebo) sed -i.bak "s/^LIBPLACEBO_REF=.*/LIBPLACEBO_REF=\"v$2\"/" download.sh; rm -f download.sh.bak ;;
    moltenvk)  sed -i.bak "s/^\(MOLTENVK_REF=\"\${MOLTENVK_REF:-v\).*\(}\"\)/\1$2\2/" build-macos.sh; rm -f build-macos.sh.bak ;;
  esac
}

if [ "$DRY_RUN" = 0 ]; then
  git config user.name "builder"
  git config user.email "builder@users.noreply.github.com"
  BASE_BRANCH="$(git rev-parse --abbrev-ref HEAD)"
fi

updates=()   # entries: "comp|cur|new"
for comp in mpv libdovi libplacebo moltenvk; do
  case "$comp" in
    mpv) cur="$(current_mpv)"; new="$(latest_mpv)" ;;
    libdovi) cur="$(current_dovi)"; new="$(latest_dovi)" ;;
    libplacebo) cur="$(current_placebo)"; new="$(latest_placebo)" ;;
    moltenvk) cur="$(current_mvk)"; new="$(latest_mvk)" ;;
  esac
  if [ -z "$cur" ] || [ -z "$new" ]; then
    echo "$comp: cannot determine versions (current='$cur' latest='$new')" >&2
    exit 1
  fi
  if ! newer "$cur" "$new"; then
    echo "$comp: up to date ($cur)"
    continue
  fi
  echo "$comp: $cur -> $new"
  updates+=("$comp|$cur|$new")
done

if [ "${#updates[@]}" = 0 ]; then
  echo "Nothing to update."
  exit 0
fi
[ "$DRY_RUN" = 1 ] && exit 0

REPO_URL="$(gh repo view --json url -q .url)"

# open_pr <branch> <title> <body>: PR + explicit build (GITHUB_TOKEN PRs do not trigger workflows)
open_pr() {
  local branch="$1" title="$2" body="$3"
  git push -q origin "$branch"
  gh pr create --base "$BASE_BRANCH" --head "$branch" --title "$title" \
    --body "$body

Build log: $REPO_URL/actions?query=branch%3A${branch//\//%2F}"
  gh workflow run macos-ci.yml --ref "$branch"
}

HINT="Merged automatically when the build on this branch is green. Red build: an issue is opened, nothing is merged (patches or context_prism.m need a manual fix)."

# one PR with all updates (auto-merged by .github/workflows/auto-merge-updates.yml when the build is green)
if true; then
  name=""; list=""
  for entry in "${updates[@]}"; do
    IFS='|' read -r comp cur new <<< "$entry"
    name="${name:+$name-}$comp-$new"; list="$list
- $comp $cur -> $new"
  done
  branch="update/$name"
  if git ls-remote --exit-code --heads origin "$branch" >/dev/null 2>&1; then
    echo "combined: branch $branch already exists, skipping"
  else
    git checkout -q -b "$branch" "$BASE_BRANCH"
    for entry in "${updates[@]}"; do
      IFS='|' read -r comp cur new <<< "$entry"
      apply "$comp" "$new"
    done
    git commit -q -am "Update all: $name"
    open_pr "$branch" "Update: ${name//-/ }" "Automated combined update:$list

$HINT"
    git checkout -q "$BASE_BRANCH"
  fi
fi
exit 0
