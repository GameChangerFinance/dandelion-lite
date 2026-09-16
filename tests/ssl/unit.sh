#!/usr/bin/env bash
set -euo pipefail
root=$(cd "$(dirname "$0")/../.." && pwd)
cd "$root"
mkdir -p tests/ssl/.work
export FIXTURE
FIXTURE=$(mktemp -d "$root/tests/ssl/.work/unit.XXXXXX")
mkdir "$FIXTURE/bin"
cp tests/ssl/fixtures/curl.sh "$FIXTURE/bin/curl"
chmod +x "$FIXTURE/bin/curl"
export PATH="$FIXTURE/bin:$PATH"
export ACME_ENABLED=true MYADDR_TOKEN='fixture&secret=with spaces' MYADDR_DOMAIN=fixture
export ACTION=set ZONE=myaddr.io. REC_TYPE=TXT REC_NAME=_acme-challenge.fixture.myaddr.io
export REC_DATA=0123456789012345678901234567890123456789012
adapter=scripts/ssl/myaddr-acme.sh
expect_failure() {
    if "$@" > "$FIXTURE/out" 2> "$FIXTURE/err"; then
        echo 'Expected failure' >&2; exit 1
    fi
    ! grep -Fq "$MYADDR_TOKEN" "$FIXTURE/out" "$FIXTURE/err"
}
"$adapter" > "$FIXTURE/out"
test ! -s "$FIXTURE/out"
grep -Fxq 'key@-' "$FIXTURE/args"
grep -Fxq "acme_challenge=$REC_DATA" "$FIXTURE/args"
grep -Fxq https://myaddr.io/update "$FIXTURE/args"
ACTION=append "$adapter"
MYADDR_DOMAIN=FIXTURE "$adapter"
expect_failure env ACME_ENABLED=false "$adapter"
expect_failure env -u ACME_ENABLED "$adapter"
expect_failure env -u MYADDR_TOKEN "$adapter"
expect_failure env -u MYADDR_DOMAIN "$adapter"
expect_failure env MYADDR_DOMAIN='../other' "$adapter"
expect_failure env REC_NAME=_acme-challenge.other.myaddr.io "$adapter"
expect_failure env ZONE=example.org "$adapter"
expect_failure env -u ZONE "$adapter"
expect_failure env REC_TYPE=A "$adapter"
expect_failure env ACTION=get "$adapter"
expect_failure env REC_DATA='x; echo injected' "$adapter"
expect_failure env MOCK_CODE=403 "$adapter"
expect_failure env MOCK_BODY="$MYADDR_TOKEN" "$adapter"
expect_failure env MOCK_FAILURE=28 "$adapter"
# Cleanup never calls curl, even when the network is unavailable.
ACTION=delete MOCK_FAILURE=99 "$adapter"
expect_failure "$adapter" unexpected
"$adapter" --help >/dev/null
expect_failure scripts/ssl/haproxy-acme.sh
expect_failure scripts/ssl/haproxy-acme.sh renew extra
expect_failure env ACME_ENABLED=false scripts/ssl/haproxy-acme.sh renew
expect_failure env -u ACME_ENABLED scripts/ssl/haproxy-acme.sh renew
echo 'PASS: adapter contract, validation, failure/timeout handling, cleanup and credential non-disclosure.'
