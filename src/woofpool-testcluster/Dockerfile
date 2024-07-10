FROM alpine:latest
RUN apk add --no-cache bash coreutils jq git wget tar

#RUN git clone -b geniusyield --single-branch https://github.com/M2tec/cardano-private-testnet-setup.git
RUN wget https://github.com/IntersectMBO/cardano-node/releases/download/8.9.3/cardano-node-8.9.3-linux.tar.gz
RUN tar xvfz cardano-node-8.9.3-linux.tar.gz ./bin/ --directory /bin
RUN rm -rf cardano-node-8.9.3-linux.tar.gz
ADD entrypoint.sh .
RUN chmod +x entrypoint.sh
ADD healthcheck.sh .
RUN chmod +x healthcheck.sh
ENTRYPOINT ["/entrypoint.sh"]

# Keep alive for debugging
# ENTRYPOINT ["tail", "-f", "/dev/null"]
