#!/bin/sh
# Test-only exec provider, following HAProxy's upstream Pebble fixture.
set -eu
case "$ACTION" in
    set|append)
        [ "$REC_NAME" = _acme-challenge.fixture.myaddr.io ]
        printf '{"host":"%s.","value":"%s"}' "$REC_NAME" "$REC_DATA" |
            curl -fsS --max-time 5 -d @- http://dns:8055/set-txt ;;
    delete) exit 0 ;;
    *) exit 1 ;;
esac
