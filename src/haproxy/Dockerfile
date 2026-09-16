# Includes HAProxy 3.4.4, Data Plane API 3.4.3, s6, curl and socat.
FROM haproxytech/haproxy-debian:s6-3.4.4@sha256:958a185b8cf4e5a77d1669a431715012804a86c7ad5de265b6c3072897dc221e

COPY scripts/ssl/haproxy-entrypoint.sh /usr/local/bin/dandelion-haproxy
RUN chmod 0755 /usr/local/bin/dandelion-haproxy \
    && chown root:root /usr/local/var/lib/dataplaneapi \
    && chmod 0700 /usr/local/var/lib/dataplaneapi \
    && sed -i \
        -e '2a umask 077' \
        -e 's@/usr/local/etc/haproxy/dataplaneapi.yml@/var/lib/dataplaneapi/dataplaneapi.yml@g' \
        -e 's@/usr/local/etc/haproxy/haproxy.cfg@/var/lib/dataplaneapi/haproxy.cfg@g' \
        -e 's@/etc/haproxy/haproxy.cfg@/var/lib/dataplaneapi/haproxy.cfg@g' \
        /etc/s6-overlay/s6-rc.d/dataplaneapi/run /etc/s6-overlay/s6-rc.d/haproxy/run
ENTRYPOINT ["/usr/local/bin/dandelion-haproxy"]
