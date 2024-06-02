ARG CARDANO_DB_SYNC_IMAGE

FROM ${CARDANO_DB_SYNC_IMAGE}

# RUN mkdir /work
# WORKDIR /work
# # GunDB peer data
RUN mkdir -p /tmp/cluster/pool-1
RUN ln -s /tmp/cluster/pool-1 /node-ipc
RUN ln -s /tmp/cluster /config
# COPY package*.json ./
# COPY unimatrix.js ./
# COPY www ./
# #COPY --from=builder /work/node_modules ./node_modules
# RUN npm install
# ADD . .
# RUN echo "{ \"sha\": \"$SHA\" }" > version.json
# RUN cat version.json
# #EXPOSE 8080
# EXPOSE 8765
# CMD ["npm","start"]
