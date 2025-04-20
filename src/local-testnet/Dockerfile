FROM alpine:latest as base

# From this tutorial:
# https://cardano-course.gitbook.io/cardano-course/handbook/setting-up-a-local-cluster/create-a-local-cluster

RUN apk add --no-cache bash coreutils jq git wget tar nano

RUN wget https://github.com/IntersectMBO/cardano-node/releases/download/9.2.1/cardano-node-9.2.1-linux.tar.gz
RUN tar xvfz cardano-node-9.2.1-linux.tar.gz ./bin/ --directory /bin
RUN rm -rf cardano-node-9.2.1-linux.tar.gz

RUN git clone https://github.com/input-output-hk/cardano-node.git

FROM base as final

WORKDIR /cardano-node
RUN  git checkout tags/9.2.1
COPY ./set-path.patch /cardano-node/set-path.patch
RUN git apply set-path.patch

RUN mkdir -p /node-ipc/node-spo2
RUN mkdir -p /node-ipc/node-spo3

COPY ./add-era-hash.sh /add-era-hash.sh 
# COPY ./remove-microseconds.sh /remove-microseconds.sh 
COPY ./sync-time.sh /sync-time.sh
COPY ./set-pgpass.sh /set-pgpass.sh 
COPY ./start-cluster.sh /start-cluster.sh 

WORKDIR /

ENTRYPOINT ["./start-cluster.sh"]

# Keep alive for debugging
# ENTRYPOINT ["tail", "-f", "/dev/null"]
