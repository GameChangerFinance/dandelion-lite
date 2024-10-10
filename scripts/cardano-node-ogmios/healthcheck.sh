
echo "NETWORK=$NETWORK"

validate_json() {
    local input="$1"
    
    # Remove leading and trailing whitespace using parameter expansion
    input="${input#"${input%%[![:space:]]*}"}"  # Remove leading whitespace
    input="${input%"${input##*[![:space:]]}"}"  # Remove trailing whitespace
    
    # Function to check matching braces and brackets
    check_braces() {
        local str="$1"
        local open_brace=0
        local open_bracket=0
        local i

        for (( i=0; i<${#str}; i++ )); do
            char="${str:i:1}"
            case "$char" in
                '{') ((open_brace++)) ;;
                '}') ((open_brace--)) ;;
                '[') ((open_bracket++)) ;;
                ']') ((open_bracket--)) ;;
            esac
            
            # Check for negative counts indicating mismatched braces/brackets
            if [[ $open_brace -lt 0 || $open_bracket -lt 0 ]]; then
                return 1
            fi
        done

        # Both counts should be zero if braces/brackets are matched
        if [[ $open_brace -ne 0 || $open_bracket -ne 0 ]]; then
            return 1
        else
            return 0
        fi
    }

    # Basic check for leading and trailing braces/brackets
    if [[ $input =~ ^\{.*\}$ ]] || [[ $input =~ ^\[.*\]$ ]]; then
        if check_braces "$input"; then
            echo "Valid JSON"
        else
            echo "Invalid JSON"
        fi
    else
        echo "Invalid JSON"
    fi
}

extract_sync_progress() {
  local json_data=$1
  local sync_progress

  sync_progress=$(echo "$json_data" | while read -r line; do
    case $line in
      *"\"syncProgress\": "*)
        # Extract the value
        value=${line#*\"syncProgress\": \"}
        value=${value%%\"*}
        echo "$value"
        ;;
    esac
  done)

  echo "$sync_progress"
}


extract_epoch() {
  local json_data=$1
  local sync_progress

  epoch=$(echo "$json_data" | while read -r line; do
    case $line in
      *"\"epoch\": "*)
        # Extract the value
        value=${line#*\"epoch\": \"}
        value=${value%%\"*}
        echo "$value"
        ;;
    esac
  done)

  echo "$epoch"
}

if [[ "$NETWORK" == "mainnet" ]]
then
    STATUS=`cardano-cli query tip --mainnet --socket-path /ipc/node.socket`
  
else
    STATUS=`cardano-cli query tip --testnet-magic 1 --socket-path /ipc/node.socket`
fi

# STATUS='{
#     "block": 2406756,
#     "epoch": 151,
#     "era": "Babbage",
#     "hash": "236e956504226ce7d1fb5e2e59f3491517f47cd547181ca4b0ea9a4727194afc",
#     "slot": 63803497,
#     "slotInEpoch": 213097,
#     "slotsToEpochEnd": 218903,
#     "syncProgress": "2.50"
# }'
# IS_JSON=$(validate_json "$STATUS")
# echo $IS_JSON

# STATUS='cardano-cli: Network.Socket.connect: <socket: 11>: does not exist (No such file or directory)'
IS_JSON=$(validate_json "$STATUS")
# echo $IS_JSON

if ! [[ $IS_JSON == "Valid JSON" ]] ; then
   echo -e "\nSocket not yet available" >&2; 
   exit 1
fi


# echo $STATUS
SYNC_PROGRESS=$(extract_sync_progress "$STATUS")
# echo "SYNC: $SYNC_PROGRESS"
EPOCH=$(extract_epoch "$STATUS")

STATUS_INTEGER=${SYNC_PROGRESS%.*}

if [ "$STATUS_INTEGER" -ge "1" ] ; then
    echo "OK - Epoch: $EPOCH, Node sync progress: $SYNC_PROGRESS %";
    exit 0;
else 
    echo "Initializing - Sync progress: $SYNC_PROGRESS % < 1%";
    exit 1;
fi

