FROM alpine:latest
RUN apk add --no-cache bash coreutils jq git
RUN git clone -b geniusyield --single-branch https://github.com/M2tec/cardano-private-testnet-setup.git
ADD bin bin
ADD entrypoint.sh .
RUN chmod +x entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]

# Keep alive for debugging
# ENTRYPOINT ["tail", "-f", "/dev/null"]
