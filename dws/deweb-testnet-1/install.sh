#!/bin/bash

source <(curl -s https://raw.githubusercontent.com/nodejumper-org/cosmos-scripts/master/utils/common.sh)

printLogo

read -r -p "Enter node moniker: " NODE_MONIKER

CHAIN_ID="deweb-testnet-1"
CHAIN_DENOM="udws"
BINARY_NAME="dewebd"
CHEAT_SHEET="https://nodejumper.io/dws-testnet/cheat-sheet"

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
rm -rf deweb
git clone https://github.com/deweb-services/deweb.git
cd deweb || return
git checkout v0.2
make install
dewebd version # 0.2

dewebd config keyring-backend test
dewebd config chain-id $CHAIN_ID
dewebd init "$NODE_MONIKER" --chain-id $CHAIN_ID

curl https://raw.githubusercontent.com/deweb-services/deweb/main/genesis.json > $HOME/.deweb/config/genesis.json
sha256sum $HOME/.deweb/config/genesis.json # 13bf101d673990cb39e6af96e3c7e183da79bd89f6d249e9dc797ae81b3573c2

curl https://raw.githubusercontent.com/encipher88/deweb/main/addrbook.json > $HOME/.deweb/config/addrbook.json
sha256sum $HOME/.deweb/config/addrbook.json # ba7bea692350ca8918542a26cabd5616dbebe1ff109092cb1e98c864da58dabf

sed -i 's|^minimum-gas-prices *=.*|minimum-gas-prices = "0.0001udws"|g' $HOME/.deweb/config/app.toml
SEEDS=""
PEERS="c5b45045b0555c439d94f4d81a5ec4d1a578f98c@dws-testnet.nodejumper.io:27656"
sed -i 's|^seeds *=.*|seeds = "'$SEEDS'"|; s|^persistent_peers *=.*|persistent_peers = "'$PEERS'"|' $HOME/.deweb/config/config.toml

# in case of pruning
sed -i 's|pruning = "default"|pruning = "custom"|g' $HOME/.deweb/config/app.toml
sed -i 's|pruning-keep-recent = "0"|pruning-keep-recent = "100"|g' $HOME/.deweb/config/app.toml
sed -i 's|pruning-interval = "0"|pruning-interval = "17"|g' $HOME/.deweb/config/app.toml

printCyan "5. Starting service and synchronization..." && sleep 1

sudo tee /etc/systemd/system/dewebd.service > /dev/null << EOF
[Unit]
Description=DWS Node
After=network-online.target
[Service]
User=$USER
ExecStart=$(which dewebd) start
Restart=on-failure
RestartSec=10
LimitNOFILE=10000
[Install]
WantedBy=multi-user.target
EOF

dewebd unsafe-reset-all

SNAP_RPC="https://dws-testnet.nodejumper.io:443"
LATEST_HEIGHT=$(curl -s $SNAP_RPC/block | jq -r .result.block.header.height); \
BLOCK_HEIGHT=$((LATEST_HEIGHT - 2000)); \
TRUST_HASH=$(curl -s "$SNAP_RPC/block?height=$BLOCK_HEIGHT" | jq -r .result.block_id.hash)

echo $LATEST_HEIGHT $BLOCK_HEIGHT $TRUST_HASH

sed -i -E "s|^(enable[[:space:]]+=[[:space:]]+).*$|\1true| ; \
s|^(rpc_servers[[:space:]]+=[[:space:]]+).*$|\1\"$SNAP_RPC,$SNAP_RPC\"| ; \
s|^(trust_height[[:space:]]+=[[:space:]]+).*$|\1$BLOCK_HEIGHT| ; \
s|^(trust_hash[[:space:]]+=[[:space:]]+).*$|\1\"$TRUST_HASH\"|" $HOME/.deweb/config/config.toml

sudo systemctl daemon-reload
sudo systemctl enable dewebd
sudo systemctl start dewebd

printLine
echo -e "Check logs:            ${CYAN}sudo journalctl -u $BINARY_NAME -f --no-hostname -o cat ${NC}"
echo -e "Check synchronization: ${CYAN}$BINARY_NAME status 2>&1 | jq .SyncInfo.catching_up${NC}"
echo -e "More commands:         ${CYAN}$CHEAT_SHEET${NC}"
