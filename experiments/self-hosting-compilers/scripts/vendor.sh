#!/usr/bin/env bash
# Vendor a pristine snapshot of an upstream compiler into compilers/<name>/.
#
# Usage: scripts/vendor.sh <name> <git-url> [ref]
#
# - Shallow-clones <git-url> (at <ref> if given, else default branch).
# - Records url + commit SHA + date + detected license into compilers/<name>/UPSTREAM.
# - Strips upstream .git history; source lands under compilers/<name>/src/.
# - Leaves any existing build.sh / notes.md / UPSTREAM.local in place.
#
# Re-running re-vendors src/ from upstream (your in-place edits to src/ are
# overwritten — commit them first, or keep changes as patches if you prefer).
set -euo pipefail

name=${1:?usage: vendor.sh <name> <git-url> [ref]}
url=${2:?usage: vendor.sh <name> <git-url> [ref]}
ref=${3:-}

root=$(git -C "$(dirname "$0")/.." rev-parse --show-toplevel)
dest="$root/compilers/$name"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

echo ">> cloning $url ${ref:+@ $ref}"
if [ -n "$ref" ]; then
  git clone --quiet "$url" "$tmp/repo"
  git -C "$tmp/repo" checkout --quiet "$ref"
else
  git clone --quiet --depth 1 "$url" "$tmp/repo"
fi

sha=$(git -C "$tmp/repo" rev-parse HEAD)
cdate=$(git -C "$tmp/repo" show -s --format=%cs HEAD)
license=$(cd "$tmp/repo" && ls LICENSE* COPYING* LICENCE* 2>/dev/null | head -1 || true)

mkdir -p "$dest"
rm -rf "$dest/src"
rm -rf "$tmp/repo/.git"
mv "$tmp/repo" "$dest/src"

cat > "$dest/UPSTREAM" <<EOF
upstream:   $url
commit:     $sha
authored:   $cdate
vendored:   $(date +%F)
license:    ${license:-UNKNOWN — check upstream}
EOF

# Stage the pristine import with -f: vendored upstreams ship their own
# .gitignore files which would otherwise hide upstream-tracked files (example
# assets, testdata, even some source) from our commits. Force-add at import
# time, while the tree is pristine (pre-build), captures everything faithfully.
git -C "$root" add -f "compilers/$name/src" "$dest/UPSTREAM"

echo ">> vendored to compilers/$name/src  (commit ${sha:0:12}, $cdate)"
echo ">> wrote compilers/$name/UPSTREAM, staged with git add -f"
[ -f "$dest/build.sh" ] || echo ">> NOTE: no build.sh yet — add compilers/$name/build.sh"
