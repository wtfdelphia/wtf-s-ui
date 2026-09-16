#!/usr/bin/env bash
# Apply 03-up-on-cloud.patch on top of the targeted cloud/main commit and
# produce a runnable panel (backend + built frontend).
#
# Usage: patch/apply.sh <target-dir>
#   <target-dir> may be empty (fresh clone) or an existing s-ui checkout.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
WORK="${1:?usage: apply.sh <target-dir>}"

REPO_URL="https://github.com/wtfdelphia/wtf-s-ui.git"
TARGET="$(python3 -c "import json; print(json.load(open('$HERE/METADATA.json'))['patch3_target'])")"

# 1) code at the exact cloud commit this patch set was built for
if [ ! -d "$WORK/.git" ]; then
  git clone "$REPO_URL" "$WORK"
fi
cd "$WORK"
git fetch origin
git checkout -f "$TARGET"

# 2) the customization itself
git apply --index "$HERE/03-up-on-cloud.patch"

# 3) frontend submodule (URL may have moved; sync first)
git submodule sync --recursive
git submodule update --init --recursive frontend

# 4) build the frontend
( cd frontend && npm ci && npm run build )

# 5) stage it where go:embed picks it up (mirrors build.sh)
mkdir -p web/html
rm -fr web/html/*
cp -R frontend/dist/* web/html/

# 6) backend build. build.sh's dev profile wants the musl/Chromium cronet
# toolchain that only the release CI provisions; on a dev box fall back to
# the test profile (same tags as release.yml's non-naive targets).
if ./build.sh; then
  :
else
  echo "build.sh dev profile unavailable (needs CI musl/cronet toolchain); using test profile" >&2
  . ./build-tags.sh
  TAGS=$(tags_for test)
  LDFLAGS=$(ldflags_for test)
  go build -ldflags "$LDFLAGS" -tags "$TAGS" -o sui main.go
fi
test -x ./sui || { echo "FAIL: sui binary not produced" >&2; exit 1; }

echo "OK: panel built in $WORK (binary: $WORK/sui)"
