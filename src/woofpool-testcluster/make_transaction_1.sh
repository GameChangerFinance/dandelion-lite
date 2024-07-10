#!/bin/bash

get_address_files() {
    podman  cp \
            gc-node-private-testcluster-1:/testcluster/private-testnet/addresses/${FILE_NAME} \
            $PWD/addresses/${FILE_NAME}
}

FILE_NAME="user1-stake.addr"
get_address_files
FILE_NAME="user1-stake.skey"
get_address_files
FILE_NAME="user1-stake.vkey"
get_address_files
FILE_NAME="user1.addr" 
get_address_files
FILE_NAME="user1.skey"
get_address_files
FILE_NAME="user1.vkey"
get_address_files
FILE_NAME="user1-stake.reg.cert"
get_address_files


