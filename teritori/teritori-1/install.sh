#!/bin/bash

source <(curl -s https://raw.githubusercontent.com/nodejumper-org/cosmos-scripts/master/utils/common.sh)

printLogo

read -r -p "Enter node moniker: " NODE_MONIKER

CHAIN_ID="teritori-1"
CHAIN_DENOM="utori"
BINARY_NAME="teritorid"
BINARY_VERSION_TAG="v1.3.0"
CHEAT_SHEET="https://nodejumper.io/teritori/cheat-sheet"

printLine
echo -e "Node moniker:       ${CYAN}$NODE_MONIKER${NC}"
echo -e "Chain id:           ${CYAN}$CHAIN_ID${NC}"
echo -e "Chain demon:        ${CYAN}$CHAIN_DENOM${NC}"
echo -e "Binary version tag: ${CYAN}$BINARY_VERSION_TAG${NC}"
printLine
sleep 1

source <(curl -s https://raw.githubusercontent.com/nodejumper-org/cosmos-scripts/master/utils/dependencies_install.sh)

printCyan "4. Building binaries..." && sleep 1

cd || return
rm -rf teritori-chain
git clone https://github.com/TERITORI/teritori-chain
cd teritori-chain || return
git checkout v1.3.0
make install
teritorid version # v1.3.0

teritorid config chain-id $CHAIN_ID
teritorid init "$NODE_MONIKER" --chain-id $CHAIN_ID

curl -Ls https://github.com/TERITORI/teritori-mainnet-genesis/blob/main/genesis.json?raw=true > $HOME/.teritorid/config/genesis.json
curl -s https://snapshots3.nodejumper.io/teritori/addrbook.json > $HOME/.teritorid/config/addrbook.json

SEEDS=""
PEERS=""
sed -i 's|^seeds *=.*|seeds = "'$SEEDS'"|; s|^persistent_peers *=.*|persistent_peers = "'$PEERS'"|' $HOME/.teritorid/config/config.toml

PRUNING_INTERVAL=$(shuf -n1 -e 11 13 17 19 23 29 31 37 41 43 47 53 59 61 67 71 73 79 83 89 97)
sed -i 's|^pruning *=.*|pruning = "custom"|g' $HOME/.teritorid/config/app.toml
sed -i 's|^pruning-keep-recent  *=.*|pruning-keep-recent = "100"|g' $HOME/.teritorid/config/app.toml
sed -i 's|^pruning-interval *=.*|pruning-interval = "'$PRUNING_INTERVAL'"|g' $HOME/.teritorid/config/app.toml
sed -i 's|^snapshot-interval *=.*|snapshot-interval = 2000|g' $HOME/.teritorid/config/app.toml

sed -i 's|^minimum-gas-prices *=.*|minimum-gas-prices = "0.0001utori"|g' $HOME/.teritorid/config/app.toml
sed -i 's|^prometheus *=.*|prometheus = true|' $HOME/.teritorid/config/config.toml

printCyan "5. Starting service and synchronization..." && sleep 1

sudo tee /etc/systemd/system/teritorid.service > /dev/null << EOF
[Unit]
Description=Teritori Node
After=network-online.target
[Service]
User=$USER
ExecStart=$(which teritorid) start
Restart=on-failure
RestartSec=10
LimitNOFILE=10000
[Install]
WantedBy=multi-user.target
EOF

teritorid tendermint unsafe-reset-all --home $HOME/.teritorid --keep-addr-book

SNAP_RPC="https://teritori.nodejumper.io:443"

LATEST_HEIGHT=$(curl -s $SNAP_RPC/block | jq -r .result.block.header.height)
BLOCK_HEIGHT=$((LATEST_HEIGHT - 2000))
TRUST_HASH=$(curl -s "$SNAP_RPC/block?height=$BLOCK_HEIGHT" | jq -r .result.block_id.hash)

echo $LATEST_HEIGHT $BLOCK_HEIGHT $TRUST_HASH

sed -i 's|^enable *=.*|enable = true|' $HOME/.teritorid/config/config.toml
sed -i 's|^rpc_servers *=.*|rpc_servers = "'$SNAP_RPC,$SNAP_RPC'"|' $HOME/.teritorid/config/config.toml
sed -i 's|^trust_height *=.*|trust_height = '$BLOCK_HEIGHT'|' $HOME/.teritorid/config/config.toml
sed -i 's|^trust_hash *=.*|trust_hash = "'$TRUST_HASH'"|' $HOME/.teritorid/config/config.toml

curl https://snapshots3.nodejumper.io/teritori/wasm.lz4 | lz4 -dc - | tar -xf - -C $HOME/.teritorid/data

sudo systemctl daemon-reload
sudo systemctl enable teritorid
sudo systemctl start teritorid

printLine
echo -e "Check logs:            ${CYAN}sudo journalctl -u $BINARY_NAME -f --no-hostname -o cat ${NC}"
echo -e "Check synchronization: ${CYAN}$BINARY_NAME status 2>&1 | jq .SyncInfo.catching_up${NC}"
echo -e "More commands:         ${CYAN}$CHEAT_SHEET${NC}"
