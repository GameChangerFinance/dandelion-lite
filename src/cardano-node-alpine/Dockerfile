FROM alpine:3.14

RUN apk add --no-cache wget tar bash coreutils ncurses jq nano nmap curl bc procps grep

# RUN wget https://github.com/IntersectMBO/cardano-node/releases/download/9.2.1/cardano-node-9.2.1-linux.tar.gz

# RUN tar -zxvf cardano-node-9.2.1-linux.tar.gz ./bin/cardano-cli
# RUN tar -zxvf cardano-node-9.2.1-linux.tar.gz ./bin/cardano-node
# RUN rm -rf cardano-node-*-linux.tar.gz
COPY cardano-node /bin/
COPY cardano-cli /bin/

# RUN wget https://raw.githubusercontent.com/cardano-community/guild-operators/refs/heads/alpha/scripts/cnode-helper-scripts/gLiveView.sh
COPY gLiveView.sh /
RUN chmod +x gLiveView.sh
COPY env /

COPY entrypoint.sh /
RUN chmod +x entrypoint.sh

COPY healthcheck.sh /
RUN chmod +x healthcheck.sh

# RUN wget https://github.com/prometheus/node_exporter/releases/download/v1.8.2/node_exporter-1.8.2.linux-amd64.tar.gz
# RUN tar xvfz node_exporter-*.*-amd64.tar.gz
# RUN rm -rf node_exporter-*.*-amd64.tar.gz
COPY node_exporter /

RUN mkdir logs

# EXPOSE 12798 

ENTRYPOINT ["/entrypoint.sh"]

# ENTRYPOINT ["tail"]
# CMD ["-f","/dev/null"]