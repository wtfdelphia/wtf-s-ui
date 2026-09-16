#!/bin/sh
set -e

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
cd "$ROOT"

if [ ! -d frontend ]; then
    echo "frontend/ is missing. Run: git submodule update --init --recursive" >&2
    exit 1
fi

(cd frontend && npm i && npm run build)

echo "Backend"

mkdir -p web/html
rm -fr web/html/*
cp -R frontend/dist/* web/html/

. "$ROOT/build-tags.sh"
TAGS=$(tags_for dev)
LDFLAGS=$(ldflags_for dev)

# Platform-specific external linker flags: the macOS linker wants
# -no_warn_duplicate_libraries; the release CI links statically against musl
# (done by CI with a musl toolchain). For a local dev build on glibc we just
# do a plain dynamic link — the static flag needs musl and cgo breaks on it.
if [ "$(uname)" = "Darwin" ]; then
    go build -ldflags "$LDFLAGS -extldflags -Wl,-no_warn_duplicate_libraries" -tags "$TAGS" -o sui main.go
else
    go build -ldflags "$LDFLAGS" -tags "$TAGS" -o sui main.go
fi
