NODE_INDEX=${HOSTNAME##*-}
echo "firehose-node Index: $NODE_INDEX"

if test -f $HOME_DIR/config/genesis.json; then
    echo "Genesis.json exists. Skipping node initialization."
else
    echo "Genesis.json does not exist. Initializing node."

    NODE_NAME=$(jq -r ".firehose_nodes[$NODE_INDEX].name" /config-graph/firehose-node.json)
    echo "firehose-node Index: $NODE_INDEX, Key name: $NODE_NAME"

    echo "Printing genesis file before init"
    ls -lrht $HOME_DIR/config

    jq -r ".firehose_nodes[$NODE_INDEX].mnemonic" /config-graph/firehose-node.json | persistenceCore init $NODE_NAME --chain-id $CHAIN_ID --home $HOME_DIR --recover
    jq -r ".firehose_nodes[$NODE_INDEX].mnemonic" /config-graph/firehose-node.json | persistenceCore keys add $NODE_NAME --recover --keyring-backend="test" --home $HOME_DIR

    # if we have GENESIS_NODE_DATA_RESOLUTION_METHOD is dynamic fetch the genesis from the GENESIS_EXPOSED_PORT on the GENESIS_HOST 
    # else fetch it directly from GENESIS_JSON_FETCH_URL
    if [ "$GENESIS_NODE_DATA_RESOLUTION_METHOD" = "DYNAMIC" ]; then
        echo "Config: DYNAMIC. Fetching genesis file from $GENESIS_HOST:$GENESIS_PORT"
        GENESIS_NODE_ID=$(curl -s http://$GENESIS_HOST:$GENESIS_PORT/node_id)
        curl http://$GENESIS_HOST:$GENESIS_PORT/genesis -o $HOME_DIR/config/genesis.json
    else
        echo "Config: STATIC. Fetching genesis file from $GENESIS_JSON_FETCH_URL"
        curl $GENESIS_JSON_FETCH_URL -o $HOME_DIR/config/genesis.json
    fi

    echo "Genesis file that we got....."
    cat $HOME_DIR/config/genesis.json

    GENESIS_NODE_P2P=$(curl -s http://$GENESIS_NODE_ID@$GENESIS_HOST:$GENESIS_PORT_P2P)
    echo "Node P2P: $GENESIS_NODE_P2P"
    sed -i "s/persistent_peers = \"\"/persistent_peers = \"$GENESIS_NODE_P2P\"/g" $HOME_DIR/config/config.toml
    sed -i 's#"tcp://127.0.0.1:26657"#"tcp://0.0.0.0:26657"#g' $HOME_DIR/config/config.toml
    sed -i 's/timeout_commit = "5s"/timeout_commit = "1s"/g' $HOME_DIR/config/config.toml
    sed -i 's/timeout_propose = "3s"/timeout_propose = "1s"/g' $HOME_DIR/config/config.toml
    sed -i 's/index_all_keys = false/index_all_keys = true/g' $HOME_DIR/config/config.toml

    SNAP_RPC="https://rpc.testnet.persistence.one:443"

    LATEST_HEIGHT=$(curl -s $SNAP_RPC/block | jq -r .result.block.header.height); \
    BLOCK_HEIGHT=$((LATEST_HEIGHT - 5000)); \
    TRUST_HASH=$(curl -s "$SNAP_RPC/block?height=$BLOCK_HEIGHT" | jq -r .result.block_id.hash)

    sed -i .bak -E "s|^(enable[[:space:]]+=[[:space:]]+).*$|\1true| ; \
    s|^(rpc_servers[[:space:]]+=[[:space:]]+).*$|\1\"$SNAP_RPC,$SNAP_RPC\"| ; \
    s|^(trust_height[[:space:]]+=[[:space:]]+).*$|\1$BLOCK_HEIGHT| ; \
    s|^(trust_hash[[:space:]]+=[[:space:]]+).*$|\1\"$TRUST_HASH\"|" $HOME_DIR/config/config.toml

    # replace seeds if the variable is not empty
    if [ ! -z "$SEEDS" ]; then
        sed -i "s/seeds = \"\"/seeds = \"$SEEDS\"/g" $HOME_DIR/config/config.toml
    fi

    echo "Printing the whole config.toml file"

    cat << END >> $HOME_DIR/config/config.toml
    #######################################################
    ###       Extractor Configuration Options     ###
    #######################################################
    [extractor]
    enabled = true
    output_file = "stdout"
END

    cat $HOME_DIR/config/config.toml    
fi


# if STATE_RESTORE_SNAPSHOT_URL is not empty url and wasm folder doesn't exist, then download and extract the snapshot


if [ ! -z "$STATE_RESTORE_SNAPSHOT_URL" ]; then

    # also verify that wasm folder is not empty, if it is empty only then download the snapshot
    if [ ! -d "$HOME_DIR/wasm" ] || [ ! "$(ls -A $HOME_DIR/wasm)" ]; then
        echo "Downloading snapshot from $STATE_RESTORE_SNAPSHOT_URL"
        curl $STATE_RESTORE_SNAPSHOT_URL -o $HOME_DIR/snapshot.tar.gz
        echo "Extracting snapshot"
        tar -xvf $HOME_DIR/snapshot.tar.gz -C $HOME_DIR
        rm -rf $HOME_DIR/snapshot.tar.gz

        # Move wasm and data folder out of `temp-testnet-snap` folder with force write 
        echo "Restoring state from snapshot"
        ls -lrht $HOME_DIR/temp-testnet-snap
        mv -f $HOME_DIR/temp-testnet-snap/wasm $HOME_DIR
        mv -f $HOME_DIR/temp-testnet-snap/data $HOME_DIR
    else
        echo "Wasm folder already exists, skipping snapshot download"
    fi
fi

# copy the firehose.yml file to the HOME_DIR because config-graph is a read-only volume
cp /config-graph/firehose.yml $HOME_DIR/config/firehose.yml

# if FIRST_STREAMBLE_BLOCK is not empty, then set the first_streamable_block in firehose.yml
if [ ! -z "$FIRST_STREAMBLE_BLOCK" ]; then
    echo "Setting common-first-streamable-block to $FIRST_STREAMBLE_BLOCK"
    sed -i "s/common-first-streamable-block: 0/common-first-streamable-block: $FIRST_STREAMBLE_BLOCK/g" $HOME_DIR/config/firehose.yml
fi