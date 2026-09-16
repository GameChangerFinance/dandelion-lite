#!/usr/bin/env bash
# Local Pebble ACME/DNS tests. Never use production credentials or storage here.
set -euo pipefail
root=$(cd "$(dirname "$0")/../.." && pwd)
cd "$root"
mkdir -p tests/ssl/.work tests/ssl/.upstream
work=$(mktemp -d "$root/tests/ssl/.work/acme.XXXXXX")
name="dandelion-acme-test-${work##*.}"
cleanup() {
    for suffix in ingress ca dns; do
        docker logs "$name-$suffix" > "$work/$suffix.log" 2>&1 || true
        docker rm -f "$name-$suffix" >/dev/null 2>&1 || true
    done
    docker network rm "$name" >/dev/null 2>&1 || true
}
trap cleanup EXIT
# Official release archives, checked against GitHub release asset digests.
for binary in pebble pebble-challtestsrv; do
    archive="tests/ssl/.upstream/$binary-linux-amd64.tar.gz"
    if [ ! -f "$archive" ]; then
        curl -fsSL --max-time 120 "https://github.com/letsencrypt/pebble/releases/download/v2.8.0/$binary-linux-amd64.tar.gz" -o "$archive"
    fi
    case "$binary" in
        pebble) hash=34595d915bbc2fc827affb3f58593034824df57e95353b031c8d5185724485ce ;;
        *) hash=a817449d1f05ae58bcb7bf073b4cebe5d31512f859ba4b83951bd825d28d2114 ;;
    esac
    printf '%s  %s\n' "$hash" "$archive" | sha256sum -c -
    tar -xzf "$archive" -C tests/ssl/.upstream
    chmod +x "tests/ssl/.upstream/$binary-linux-amd64/linux/amd64/$binary"
done
mkdir -p "$work/config" "$work/ssl" "$work/www" "$work/ca"
cp configs/haproxy/haproxy.cfg configs/haproxy/dataplaneapi.yml "$work/config/"
printf '.* *\n' > "$work/config/origin-whitelist.map"
touch "$work/config/ip-blacklist.lst"
printf '{}\n' > "$work/www/manifest.json"
printf 'fixture home\n' > "$work/www/index.html"
openssl req -x509 -newkey rsa:2048 -nodes -days 1 -subj /CN=pebble \
    -addext subjectAltName=DNS:pebble -addext basicConstraints=critical,CA:TRUE \
    -keyout "$work/ca/key.pem" -out "$work/ca/cert.pem" 2>"$work/openssl.log"
jq -n '{pebble:{listenAddress:"0.0.0.0:14000",managementListenAddress:"0.0.0.0:15000",certificate:"/fixtures/ca/cert.pem",privateKey:"/fixtures/ca/key.pem",httpPort:5002,tlsPort:5001,externalAccountBindingRequired:false}}' > "$work/pebble.json"
# Only fixture copies use the local CA and test provider.
sed -i \
    -e 's@https://acme-v02.api.letsencrypt.org/directory@https://pebble:14000/dir@' \
    -e 's@command=/scripts/ssl/myaddr-acme.sh@command=/tests/dns01.sh@' \
    -e '/httpclient.resolvers.prefer ipv4/a\  httpclient.ssl.ca-file /fixtures/ca/cert.pem' \
    "$work/config/haproxy.cfg"
docker network create --internal "$name" >/dev/null
docker run -d --name "$name-dns" --network "$name" --network-alias dns \
    -v "$root/tests/ssl/.upstream/pebble-challtestsrv-linux-amd64/linux/amd64/pebble-challtestsrv:/test-dns:ro" \
    dandelion-ssl-test:local /test-dns -dns01 :53 -defaultIPv6 '' >/dev/null
dnsip=$(docker inspect --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$name-dns")
docker exec "$name-dns" curl -fsS -d "{\"ip\":\"$dnsip\"}" http://127.0.0.1:8055/set-default-ipv4
docker run -d --name "$name-ca" --network "$name" --network-alias pebble \
    -e PEBBLE_VA_NOSLEEP=1 -e PEBBLE_AUTHZREUSE=0 \
    -v "$work:/fixtures:ro" \
    -v "$root/tests/ssl/.upstream/pebble-linux-amd64/linux/amd64/pebble:/test-ca:ro" \
    dandelion-ssl-test:local /test-ca -config /fixtures/pebble.json -dnsserver "$dnsip:53" >/dev/null
hosts=()
while read -r host; do hosts+=(--add-host "$host:127.0.0.1"); done < <(
    awk '$1 == "server" {split($3,a,":"); print a[1]}' configs/haproxy/haproxy.cfg | sort -u)
start_ingress() {
    docker run -d --name "$name-ingress" --network "$name" --dns "$dnsip" "${hosts[@]}" \
        -e HAPROXY_MAX_CONNECTIONS=100 -e HAPROXY_WORKER_THREADS=1 \
        -e HAPROXY_IP_BLACKLIST=/usr/local/etc/haproxy/ip-blacklist.lst \
        -e HAPROXY_ORIGIN_WHITELIST=/usr/local/etc/haproxy/origin-whitelist.map \
        -e TLS_ENABLED=true -e ACME_ENABLED=true -e MYADDR_DOMAIN=fixture -e MYADDR_TOKEN=fixture-token \
        -e DPAPI_ACME_PROPAGTIMEOUT_SEC=-1 \
        -v "$work/config:/usr/local/etc/haproxy:ro" -v "$work/ssl:/var/lib/haproxy/ssl" \
        -v "$work/www:/usr/local/etc/www:ro" -v "$work/ca:/fixtures/ca:ro" \
        -v "$root/tests/ssl/fixtures:/tests:ro" -v "$root/scripts/ssl:/scripts/ssl:ro" \
        dandelion-ssl-test:local >/dev/null
}
wait_cert() {
    local previous=${1:-none}
    for attempt in {1..90}; do
        if docker exec "$name-ingress" sh -c 'test -s /var/lib/haproxy/ssl/server.pem' >/dev/null 2>&1; then
            current=$(docker exec "$name-ingress" sh -c "sha256sum /var/lib/haproxy/ssl/server.pem | cut -d' ' -f1")
            if [ "$current" != "$previous" ]; then return; fi
        fi
        sleep 1
    done
    echo 'Certificate was not persisted; inspect the fixture logs.' >&2
    return 1
}
wait_ssl_mode() {
    local file=$1 mode=$2
    for attempt in {1..20}; do
        if docker exec "$name-ingress" sh -c "[ -e /var/lib/haproxy/ssl/$file ] && [ \"\$(stat -c %a /var/lib/haproxy/ssl/$file)\" = $mode ]" >/dev/null 2>&1; then return; fi
        sleep 1
    done
    echo "SSL file mode did not settle to $mode: $file" >&2
    return 1
}
ssl_sha() {
    docker exec "$name-ingress" sh -c "sha256sum /var/lib/haproxy/ssl/server.pem | cut -d' ' -f1"
}
start_ingress
wait_cert
wait_ssl_mode server.pem 600
wait_ssl_mode myaddr.account.key 600
first=$(ssl_sha)
docker exec "$name-ingress" /scripts/ssl/haproxy-acme.sh status
docker exec "$name-ingress" /scripts/ssl/haproxy-acme.sh renew
wait_cert "$first"
wait_ssl_mode server.pem 600
second=$(ssl_sha)
test "$(stat -c %a "$work/ssl")" = 700
test "$(stat -c %a "$work/ssl/server.pem")" = 600
test "$(stat -c %a "$work/ssl/myaddr.account.key")" = 600
docker exec --user 65534 "$name-ingress" sh -c 'test ! -r /var/lib/haproxy/ssl/server.pem'
check_served_certificate() {
    docker exec "$name-ingress" curl -ks --output /dev/null --write-out '%{certs}' \
        https://127.0.0.1:8053/manifest > "$work/served.txt"
    sed -n '/-----BEGIN CERTIFICATE-----/,/-----END CERTIFICATE-----/p' "$work/served.txt" > "$work/served.pem"
    test "$(openssl x509 -in "$work/served.pem" -noout -fingerprint -sha256)" = \
        "$(docker exec "$name-ingress" openssl x509 -in /var/lib/haproxy/ssl/server.pem -noout -fingerprint -sha256)"
}
check_served_certificate
docker exec "$name-ingress" curl -ksf https://127.0.0.1:8053/manifest > "$work/response"
test "$(cat "$work/response")" = '{}'
docker logs "$name-ingress" > "$work/issuance.log" 2>&1
docker rm -f "$name-ingress" >/dev/null
start_ingress
sleep 4
test "$(ssl_sha)" = "$second"
wait_ssl_mode server.pem 600
docker exec "$name-ingress" curl -ksf https://127.0.0.1:8053/manifest >/dev/null
check_served_certificate
# Outage must not replace the last valid certificate or interrupt TLS.
docker stop "$name-ca" >/dev/null
docker exec "$name-ingress" /scripts/ssl/haproxy-acme.sh renew
sleep 5
test "$(ssl_sha)" = "$second"
docker exec "$name-ingress" curl -ksf https://127.0.0.1:8053/manifest >/dev/null
check_served_certificate
# An expired persisted certificate must renew without an admin command.
docker rm -f "$name-ingress" >/dev/null
docker start "$name-ca" >/dev/null
docker run --rm -v "$work/ssl:/ssl" dandelion-ssl-test:local sh -c '
    openssl pkey -in /ssl/server.pem -out /ssl/expired-key.pem
    openssl x509 -in /ssl/server.pem -signkey /ssl/expired-key.pem \
        -not_before 20250101000000Z -not_after 20250102000000Z -out /ssl/expired-cert.pem
    cat /ssl/expired-key.pem /ssl/expired-cert.pem > /ssl/server.pem
    chmod 0600 /ssl/server.pem
    rm -f /ssl/expired-key.pem /ssl/expired-cert.pem
'
start_ingress
wait_cert "$second"
wait_ssl_mode server.pem 600
check_served_certificate
echo 'PASS: initial DNS-01 issuance, requested/due renewal, persistence, recreation and CA-outage retention.'
printf 'Fixture logs: tests/ssl/.work/%s\n' "${work##*/}"
