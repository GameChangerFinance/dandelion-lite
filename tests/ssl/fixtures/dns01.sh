#!/bin/sh
# Test-only exec provider, following HAProxy's upstream Pebble fixture.
set -eu
case "$ACTION" in
    set|append)
        record=${REC_NAME%.}
        zone=${ZONE%.}
        case "$record" in *."$zone") ;; *) record="$record.$zone" ;; esac
        [ "$record" = _acme-challenge.fixture.myaddr.io ]
        printf '{"host":"%s.","value":"%s"}' "$record" "$REC_DATA" |
            curl -fsS --max-time 5 -d @- http://dns:8055/set-txt ;;
    delete) exit 0 ;;
    *) exit 1 ;;
esac
