#!/usr/bin/env bash
# Host helpers are copied into a disposable repository and use command shims.
set -euo pipefail
root=$(cd "$(dirname "$0")/../.." && pwd)
cd "$root"
mkdir -p tests/ssl/.work
work=$(mktemp -d "$root/tests/ssl/.work/scripts.XXXXXX")
mkdir -p "$work/repo/scripts/ssl" "$work/repo/configs/ssl" "$work/repo/secrets/ssl"
cp scripts/ssl/rotate-ssl-and-restart-haproxy.sh "$work/repo/scripts/ssl/"
export TEST_CALLS="$work/docker-calls" TEST_AUTOMATIC=false TEST_DOCKER_RESULT=0
docker() {
    printf '%s\n' "$*" >> "$TEST_CALLS"
    case " $* " in
        *' config --format json '*) printf '{"services":{"haproxy":{"environment":{"ACME_ENABLED":"%s"}}}}\n' "$TEST_AUTOMATIC" ;;
        *) return "$TEST_DOCKER_RESULT" ;;
    esac
}
export -f docker
rotate="$work/repo/scripts/ssl/rotate-ssl-and-restart-haproxy.sh"
expect_failure() { if "$@" > "$work/out" 2> "$work/err"; then echo 'Expected failure' >&2; exit 1; fi; }
expect_failure "$rotate" --compose-file
grep -q Usage "$work/err"
"$rotate" > "$work/out"
test ! -e "$TEST_CALLS"
touch "$work/repo/configs/ssl/server.pem"
expect_failure "$rotate"
printf 'new fixture\n' > "$work/repo/configs/ssl/server.pem"
printf 'old fixture\n' > "$work/repo/secrets/ssl/server.pem"
TEST_AUTOMATIC=true expect_failure "$rotate"
grep -q 'old fixture' "$work/repo/secrets/ssl/server.pem"
ln -s "$work/repo/secrets/ssl/server.pem" "$work/repo/secrets/ssl/server.pem.old.1"
expect_failure "$rotate"
grep -q symlink "$work/err"
# Unlink only the exact disposable fixture link.
unlink "$work/repo/secrets/ssl/server.pem.old.1"
"$rotate" --project-name fixture > "$work/out"
grep -q 'new fixture' "$work/repo/secrets/ssl/server.pem"
grep -q 'old fixture' "$work/repo/secrets/ssl/server.pem.old.1"
test "$(stat -c %a "$work/repo/secrets/ssl/server.pem")" = 600
grep -q 'restart haproxy' "$TEST_CALLS"

# Extract only the relevant functions, never source real .env or startup code.
source <(sed -n '/^process_args() {/,/^}/p' "$root/scripts/dandoman.sh")
source <(sed -n '/^main() {/,/^}/p' "$root/scripts/dandoman.sh")
append_path_to_shell_configs() { :; }
KLITE_HOME="$work/repo"
show_ui=false
printf 'PROJ_NAME=fixture\n' > "$work/repo/.env"
TEST_DOCKER_RESULT=23
set +e
main --ssl-renew > "$work/out" 2> "$work/err"
result=$?
set -e
test "$result" = 23
grep -q 'exec -T haproxy /scripts/ssl/haproxy-acme.sh renew' "$TEST_CALLS"
TEST_DOCKER_RESULT=0
main --ssl-renew > "$work/out"
cd "$root"

# Test the wizard's changed SSL choice, without its deployment/firewall steps.
source <(sed -n '/^update_env_var() {/,/^}/p' scripts/wizard.sh)
gum() { return "${TEST_CONFIRM:-0}"; }
export DOMAIN=myaddr.io MYADDR_TOKEN=fixture MYADDR_DOMAIN=fixture
for TEST_CONFIRM in 0 1; do
    cd "$work/repo"
    source <(sed -n '/^TLS_ENABLED=false$/,/^update_env_var ".env" "ACME_ENABLED"/p' "$root/scripts/wizard.sh") > "$work/out"
    if [ "$TEST_CONFIRM" = 0 ]; then
        grep -qx TLS_ENABLED=true .env
        grep -qx ACME_ENABLED=true .env
    else
        grep -qx TLS_ENABLED=false .env
        grep -qx ACME_ENABLED=false .env
    fi
done
cd "$root"

# DDNS keeps IP updates and excludes a stale TXT value only in automatic mode.
curl() {
    case "$*" in *api.ipify.org*) printf '192.0.2.1'; return ;; esac
    [ "$(cat)" = "$MYADDR_TOKEN" ]
    printf '%s\n' "$@" > "$TEST_CALLS"
    printf OK
}
export -f curl
export MYADDR_ACME_CHALLENGE=stale MYADDR_IP=192.0.2.2
ACME_ENABLED=true bash scripts/cron/myaddrdns/update.sh > "$work/out"
grep -Fxq ip=192.0.2.2 "$TEST_CALLS"
! grep -q acme_challenge "$TEST_CALLS"
ACME_ENABLED=false bash scripts/cron/myaddrdns/update.sh > "$work/out"
grep -Fxq acme_challenge=stale "$TEST_CALLS"

# Generate from the real entrypoint with only paths and cron executables isolated.
mkdir -p "$work/cron"
cp -R scripts/cron/cardano-graphql scripts/cron/dandelion-lite scripts/cron/koios-artifacts-1.3.2 \
    scripts/cron/duckdns scripts/cron/myaddrdns "$work/cron/"
crontab() { :; }
crond() { :; }
exec() { "$@"; }
source <(sed "s@/etc/cron.d/@$work/cron/@g" scripts/cron/entrypoint.sh) > "$work/out"
unset -f exec
! grep -qi certbot "$work/cron/init_cron"
grep -Fq '*/3 * * * * /scripts/cron/myaddrdns/update.sh' "$work/cron/init_cron"
if [ "${1:-}" = --regenerate-cron ]; then
    cp "$work/cron/init_cron" "$root/scripts/cron/init_cron"
else
    cmp "$work/cron/init_cron" "$root/scripts/cron/init_cron"
fi
# No route, CORS, rate limit, backend or timeout edit is hidden in the TLS migration.
diff -u <(git show 8452d05:configs/haproxy/haproxy.cfg | sed -n '/  # Manual IP blacklisting/,$p') \
    <(sed -n '/  # Manual IP blacklisting/,$p' configs/haproxy/haproxy.cfg)
diff -u <(git show 8452d05:configs/haproxy/haproxy.cfg | sed -n '/^defaults$/,/^frontend app$/p' | sed '$d') \
    <(sed -n '/^defaults$/,/^# TLS mode/p' configs/haproxy/haproxy.cfg | sed '$d')
echo 'PASS: manual rotation, CLI failure propagation, wizard SSL choice, DDNS, generated cron and route invariance.'
