# Includes HAProxy 3.4.8, Data Plane API, gopherd, curl and socat.
FROM haproxytech/haproxy-debian:s6-3.4.8@sha256:304b1a2bccf74e6f9fd150390e7c66307c66bd36ab3ff226c253293a4449bea1

COPY scripts/ssl/haproxy-entrypoint.sh /usr/local/bin/dandelion-haproxy
RUN chmod 0755 /usr/local/bin/dandelion-haproxy \
    && chown root:root /usr/local/var/lib/dataplaneapi \
    && chmod 0700 /usr/local/var/lib/dataplaneapi \
    && sed -i \
        -e 's@/usr/local/etc/haproxy/dataplaneapi.yml@/var/lib/dataplaneapi/dataplaneapi.yml@g' \
        -e 's@/usr/local/etc/haproxy/haproxy.cfg@/var/lib/dataplaneapi/haproxy.cfg@g' \
        -e 's@/etc/haproxy/haproxy.cfg@/var/lib/dataplaneapi/haproxy.cfg@g' \
        /etc/gopherd/gopherd.yml /etc/gopherd/gopherd-sigusr1.yml \
        /etc/gopherd/init/01-dataplaneapi
ENTRYPOINT ["/usr/local/bin/dandelion-haproxy"]
