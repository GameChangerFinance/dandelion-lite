#!/usr/bin/env bash
# Disposable smoke test: no production Compose, credentials, volumes or ports.
set -euo pipefail
root=$(cd "$(dirname "$0")/../.." && pwd)
cd "$root"
mkdir -p tests/ssl/.work
work=$(mktemp -d "$root/tests/ssl/.work/run.XXXXXX")
name="dandelion-ssl-test-${work##*.}"
trap 'docker logs "$name" > "$work/final.log" 2>&1 || true; docker rm -f "$name" >/dev/null 2>&1 || true' EXIT
if [ "${1:-}" != --skip-build ]; then
    tar -c src/haproxy/Dockerfile scripts/ssl/haproxy-entrypoint.sh |
        docker build -t dandelion-ssl-test:local -f src/haproxy/Dockerfile -
fi
mkdir -p "$work/config" "$work/ssl" "$work/www"
cp configs/haproxy/haproxy.cfg configs/haproxy/dataplaneapi.yml "$work/config/"
printf '.* *\n' > "$work/config/origin-whitelist.map"
touch "$work/config/ip-blacklist.lst"
printf '{}\n' > "$work/www/manifest.json"
printf 'fixture home\n' > "$work/www/index.html"
openssl req -x509 -newkey rsa:2048 -nodes -days 1 -subj /CN=fixture.myaddr.io \
    -keyout "$work/ssl/key.pem" -out "$work/ssl/cert.pem" 2>"$work/openssl.log"
cat "$work/ssl/key.pem" "$work/ssl/cert.pem" > "$work/ssl/server.pem"
chmod 644 "$work/ssl/server.pem"
# Resolve backend names locally; no backend service is launched.
hosts=()
while read -r host; do hosts+=(--add-host "$host:127.0.0.1"); done < <(
    awk '$1 == "server" {split($3,a,":"); print a[1]}' configs/haproxy/haproxy.cfg | sort -u)
base_args=(--network none
    -e HAPROXY_MAX_CONNECTIONS=100 -e HAPROXY_WORKER_THREADS=1
    -e HAPROXY_IP_BLACKLIST=/usr/local/etc/haproxy/ip-blacklist.lst
    -e HAPROXY_ORIGIN_WHITELIST=/usr/local/etc/haproxy/origin-whitelist.map
    -e TLS_ENABLED=true -e ACME_ENABLED= -e MYADDR_DOMAIN=fixture -e MYADDR_TOKEN=
    -v "$work/config:/usr/local/etc/haproxy:ro"
    -v "$work/ssl:/var/lib/haproxy/ssl"
    -v "$work/www:/usr/local/etc/www:ro"
    -v "$root/scripts/ssl:/scripts/ssl:ro")
docker run --rm "${base_args[@]}" -e TLS_ENABLED=false \
    dandelion-ssl-test:local haproxy -c -f /usr/local/etc/haproxy/haproxy.cfg
args=("${base_args[@]}" "${hosts[@]}")
docker run --rm "${args[@]}" dandelion-ssl-test:local haproxy -c -f /usr/local/etc/haproxy/haproxy.cfg
docker run -d --name "$name" "${args[@]}" dandelion-ssl-test:local >/dev/null
for attempt in {1..20}; do
    if docker exec "$name" curl -ksf https://127.0.0.1:8053/manifest > "$work/response"; then break; fi
    sleep 1
done
docker logs "$name" > "$work/ingress.log" 2>&1
test "$(cat "$work/response")" = '{}'
grep -q 'ℹ️ Manual TLS is enabled; HAProxy will use secrets/ssl/server.pem.' "$work/ingress.log"
grep -q '✅ TLS certificate is present, protected with 0600, and valid until ' "$work/ingress.log"
for attempt in {1..40}; do
    if docker exec "$name" sh -c 'test -S /var/run/dataplaneapi.sock'; then break; fi
    sleep 1
done
docker exec "$name" sh -c 'test -S /var/run/dataplaneapi.sock'
docker exec "$name" sh -c 'curl --unix-socket /var/run/dataplaneapi.sock -s -o /dev/null -w "%{http_code}" http://localhost/v3/info' > "$work/api-status"
test "$(cat "$work/api-status")" = 401
docker exec "$name" sh -c 'stat -c "%a" /var/run/dataplaneapi.sock /var/run/haproxy-master.sock'
test "$(stat -c %a "$work/ssl")" = 700
test "$(stat -c %a "$work/ssl/server.pem")" = 600
docker exec --user 65534 "$name" sh -c 'test ! -r /var/lib/haproxy/ssl/server.pem'
docker logs "$name" > "$work/ingress.log" 2>&1
docker rm -f "$name" >/dev/null

# Fresh automatic mode must parse without a dummy PEM. Network stays disabled.
mv "$work/ssl/server.pem" "$work/ssl/manual.pem"
if docker run --rm "${args[@]}" dandelion-ssl-test:local > "$work/missing-pem.log" 2>&1; then
    echo 'Manual TLS unexpectedly started without secrets/ssl/server.pem.' >&2
    exit 1
fi
grep -q 'TLS_ENABLED=true with ACME disabled requires secrets/ssl/server.pem' "$work/missing-pem.log"
docker run --rm "${args[@]}" -e ACME_ENABLED=true -e MYADDR_TOKEN=fixture-token \
    dandelion-ssl-test:local haproxy -c -f /usr/local/etc/haproxy/haproxy.cfg
# Plaintext must start without any PEM even when automatic mode is requested.
docker run --rm "${args[@]}" -e ACME_ENABLED=true -e MYADDR_TOKEN=fixture-token \
    -e TLS_ENABLED=false \
    dandelion-ssl-test:local haproxy -c -f /usr/local/etc/haproxy/haproxy.cfg
docker run -d --name "$name" "${args[@]}" -e ACME_ENABLED=true -e MYADDR_TOKEN=fixture-token \
    -e TLS_ENABLED=false \
    dandelion-ssl-test:local >/dev/null
for attempt in {1..20}; do
    if docker exec "$name" curl -sf http://127.0.0.1:8053/manifest > "$work/plain-response"; then break; fi
    sleep 1
done
test "$(cat "$work/plain-response")" = '{}'
test ! -f "$work/ssl/server.pem"
if docker exec "$name" /scripts/ssl/haproxy-acme.sh renew > "$work/plain-renew.log" 2>&1; then
    echo 'Plaintext unexpectedly accepted automatic renewal.' >&2
    exit 1
fi
printf 'PASS: manual TLS/plaintext runtime, local-only API authentication and automatic configuration.\n'
printf 'Fixture logs: tests/ssl/.work/%s\n' "${work##*/}"
