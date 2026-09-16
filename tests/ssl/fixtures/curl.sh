#!/bin/sh
set -eu
printf '%s\n' "$@" > "$FIXTURE/args"
token=$(cat)
[ "$token" = "$MYADDR_TOKEN" ] || exit 98
case "$(cat "$FIXTURE/args")" in *"$MYADDR_TOKEN"*) exit 99 ;; esac
[ "${MOCK_FAILURE:-0}" = 0 ] || exit "$MOCK_FAILURE"
printf '%s\n%s' "${MOCK_BODY:-OK}" "${MOCK_CODE:-200}"
