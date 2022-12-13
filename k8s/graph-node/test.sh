NODE_INDEX=${HOSTNAME##*-}
echo "firehose-node Index: $NODE_INDEX"

rm -rf $HOME_DIR/*

NODE_NAME=$(jq -r ".firehose_nodes[$NODE_INDEX].name" /configs-graph/firehose-node.json)
echo "firehose-node Index: $NODE_INDEX, Key name: $NODE_NAME"

echo "Printing genesis file before init"
ls -lrht $HOME_DIR/config

jq -r ".firehose_nodes[$NODE_INDEX].mnemonic" /configs-graph/firehose-node.json | persistenceCore init $NODE_NAME --chain-id $CHAIN_ID --home $HOME_DIR --recover
jq -r ".firehose_nodes[$NODE_INDEX].mnemonic" /configs-graph/firehose-node.json | persistenceCore keys add $NODE_NAME --recover --keyring-backend="test" --home $HOME_DIR

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

sed -i 's/seeds = \"\"/seeds = \"aeb1a074c6cbb00e32f9380cbf11c960e9b165ea@13.125.252.209:26656\"/g' $HOME_DIR/config/config.toml

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