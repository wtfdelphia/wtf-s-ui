#!/usr/bin/env bash
# Verify the three patches in this directory against their target bases,
# and check the dev-patch branch semantics. Run from any clone that has
# the up/cloud remotes configured (the main repo does).
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "$HERE/.." && pwd)"
cd "$REPO"

BASE="7cfb1a7"
UP_SHA="$(python3 -c "import json; print(json.load(open('$HERE/METADATA.json'))['up_sha'])")"
CLOUD_SHA="$(python3 -c "import json; print(json.load(open('$HERE/METADATA.json'))['cloud_sha'])")"
FE_SHA="$(python3 -c "import json; print(json.load(open('$HERE/METADATA.json'))['frontend_sha'])")"

fail() { echo "FAIL: $*" >&2; exit 1; }

echo "== 1) apply --check on each target base =="
git worktree add -f /tmp/verify-01 "$BASE" >/dev/null
(cd /tmp/verify-01 && git apply --check "$HERE/01-up-main.patch") \
  || fail "01 does not apply cleanly on $BASE"
git worktree remove -f /tmp/verify-01

git worktree add -f /tmp/verify-02 "$BASE" >/dev/null
(cd /tmp/verify-02 && git apply --check "$HERE/02-cloud-main.patch") \
  || fail "02 does not apply cleanly on $BASE"
git worktree remove -f /tmp/verify-02

git worktree add -f /tmp/verify-03 "$CLOUD_SHA" >/dev/null
(cd /tmp/verify-03 && git apply --check "$HERE/03-up-on-cloud.patch") \
  || fail "03 does not apply cleanly on $CLOUD_SHA"

echo "== 2) 01 reproduces up/main tree =="
(cd /tmp/verify-03 && true) # keep worktree pattern consistent
git worktree add -f /tmp/verify-01 "$BASE" >/dev/null
(cd /tmp/verify-01 && git apply --index "$HERE/01-up-main.patch" \
  && git diff "$UP_SHA" --exit-code) || fail "01 result differs from up/main"
git worktree remove -f /tmp/verify-01

echo "== 3) 02 reproduces cloud/main tree =="
git worktree add -f /tmp/verify-02 "$BASE" >/dev/null
(cd /tmp/verify-02 && git apply --index "$HERE/02-cloud-main.patch" \
  && git diff "$CLOUD_SHA" --exit-code) || fail "02 result differs from cloud/main"
git worktree remove -f /tmp/verify-02

echo "== 4) 03 reproduces dev-custom tree =="
(cd /tmp/verify-03 && git apply --index "$HERE/03-up-on-cloud.patch" \
  && git diff dev-custom --exit-code) || fail "03 result differs from dev-custom"
git worktree remove -f /tmp/verify-03

echo "== 5) dev-patch semantics: only patch/ and docs/ differ from $BASE =="
[ -z "$(git diff "$BASE" dev-patch -- . ':!patch' ':!docs')" ] \
  || fail "dev-patch carries changes outside patch/ and docs/"

echo "== 6) submodule pin matches METADATA =="
ACTUAL="$(git ls-tree dev-custom frontend | awk '{print $3}')"
[ "$ACTUAL" = "$FE_SHA" ] || fail "frontend gitlink $ACTUAL != METADATA $FE_SHA"

echo "== 7) release-equivalent build on dev-custom (frontend + backend) =="
# build.sh's dev profile needs the musl/Chromium cronet toolchain that only
# the release CI provisions; locally we use the test profile (same tags as
# release.yml's non-naive targets, minus naive) and dynamic linking.
git worktree add -f /tmp/verify-build dev-custom >/dev/null
(
  cd /tmp/verify-build
  git submodule update --init frontend
  ( cd frontend && npm ci && npm run build )
  mkdir -p web/html
  rm -fr web/html/*
  cp -R frontend/dist/* web/html/
  . ./build-tags.sh
  TAGS=$(tags_for test)
  LDFLAGS=$(ldflags_for test)
  go build -ldflags "$LDFLAGS" -tags "$TAGS" -o sui main.go
  test -x ./sui || fail "sui binary not produced"
) || fail "release-equivalent build failed on dev-custom"
git worktree remove -f /tmp/verify-build

echo "ALL CHECKS PASSED"
