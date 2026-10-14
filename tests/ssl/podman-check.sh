#!/usr/bin/env bash
# Reuse the tested Docker image, without touching the operator's Podman storage.
set -euo pipefail
root=$(cd "$(dirname "$0")/../.." && pwd)
cd "$root"
export SSL_TEST_ROOT="$root"
mkdir -p .ssl-test/run .ssl-test/tmp tests/ssl/.work/podman-root
chmod 700 .ssl-test/run .ssl-test/tmp
export XDG_RUNTIME_DIR="$root/.ssl-test/run"
docker save dandelion-ssl-test:local -o tests/ssl/.work/haproxy-test-image.tar
podman --root "$root/tests/ssl/.work/podman-root" --runroot "$root/.ssl-test/run" \
    --tmpdir "$root/.ssl-test/tmp" --storage-driver vfs load -i tests/ssl/.work/haproxy-test-image.tar
docker() {
    command podman --root "$SSL_TEST_ROOT/tests/ssl/.work/podman-root" \
        --runroot "$SSL_TEST_ROOT/.ssl-test/run" --tmpdir "$SSL_TEST_ROOT/.ssl-test/tmp" \
        --storage-driver vfs "$@"
}
export -f docker
bash tests/ssl/container-check.sh --skip-build
