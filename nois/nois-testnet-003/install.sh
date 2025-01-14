#!/bin/bash

source <(curl -s https://raw.githubusercontent.com/nodejumper-org/cosmos-scripts/master/utils/common.sh)

printLogo

read -r -p "Enter node moniker: " NODE_MONIKER

CHAIN_ID="nois-testnet-003"
CHAIN_DENOM="unois"
BINARY_NAME="noisd"
BINARY_VERSION_TAG="v0.29.0-rc2"
CHEAT_SHEET="https://nodejumper.io/nois-testnet/cheat-sheet"

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
rm -rf full-node
git clone https://github.com/noislabs/full-node.git
cd full-node/full-node/ || return
git checkout nois-testnet-003
./build.sh
mkdir -p $HOME/go/bin
sudo mv out/noisd $HOME/go/bin/noisd
noisd version # 0.29.0-rc2

noisd config keyring-backend test
noisd config chain-id $CHAIN_ID
noisd init "$NODE_MONIKER" --chain-id $CHAIN_ID

curl -s https://raw.githubusercontent.com/noislabs/testnets/main/nois-testnet-003/genesis.json > $HOME/.noisd/config/genesis.json
curl -s https://snapshots3-testnet.nodejumper.io/nois-testnet/addrbook.json > $HOME/.noisd/config/addrbook.json

SEEDS=""
PEERS=""
sed -i 's|^seeds *=.*|seeds = "'$SEEDS'"|; s|^persistent_peers *=.*|persistent_peers = "'$PEERS'"|' $HOME/.noisd/config/config.toml

PRUNING_INTERVAL=$(shuf -n1 -e 11 13 17 19 23 29 31 37 41 43 47 53 59 61 67 71 73 79 83 89 97)
sed -i 's|^pruning *=.*|pruning = "custom"|g' $HOME/.noisd/config/app.toml
sed -i 's|^pruning-keep-recent  *=.*|pruning-keep-recent = "100"|g' $HOME/.noisd/config/app.toml
sed -i 's|^pruning-interval *=.*|pruning-interval = "'$PRUNING_INTERVAL'"|g' $HOME/.noisd/config/app.toml
sed -i 's|^snapshot-interval *=.*|snapshot-interval = 2000|g' $HOME/.noisd/config/app.toml

sed -i 's|^minimum-gas-prices *=.*|minimum-gas-prices = "0.005unois"|g' $HOME/.noisd/config/app.toml
sed -i 's|^prometheus *=.*|prometheus = true|' $HOME/.noisd/config/config.toml
sed -i 's|^timeout_propose *=.*|timeout_propose = "2000ms"|' $HOME/.noisd/config/config.toml
sed -i 's|^timeout_propose_delta *=.*|timeout_propose_delta = "500ms"|' $HOME/.noisd/config/config.toml
sed -i 's|^timeout_prevote *=.*|timeout_prevote = "1s"|' $HOME/.noisd/config/config.toml
sed -i 's|^timeout_prevote_delta *=.*|timeout_prevote_delta = "500ms"|' $HOME/.noisd/config/config.toml
sed -i 's|^timeout_precommit *=.*|timeout_precommit = "1s"|' $HOME/.noisd/config/config.toml
sed -i 's|^timeout_precommit_delta *=.*|timeout_precommit_delta = "500ms"|' $HOME/.noisd/config/config.toml
sed -i 's|^timeout_commit *=.*|timeout_commit = "1800ms"|' $HOME/.noisd/config/config.toml

printCyan "5. Starting service and synchronization..." && sleep 1

sudo tee /etc/systemd/system/noisd.service > /dev/null << EOF
[Unit]
Description=Noisd Node
After=network-online.target
[Service]
User=$USER
ExecStart=$(which noisd) start
Restart=on-failure
RestartSec=10
LimitNOFILE=10000
[Install]
WantedBy=multi-user.target
EOF

noisd tendermint unsafe-reset-all --home $HOME/.noisd --keep-addr-book

SNAP_RPC="https://nois-testnet.nodejumper.io:443"

LATEST_HEIGHT=$(curl -s $SNAP_RPC/block | jq -r .result.block.header.height)
BLOCK_HEIGHT=$((LATEST_HEIGHT - 2000))
TRUST_HASH=$(curl -s "$SNAP_RPC/block?height=$BLOCK_HEIGHT" | jq -r .result.block_id.hash)

echo $LATEST_HEIGHT $BLOCK_HEIGHT $TRUST_HASH

sed -i 's|^enable *=.*|enable = true|' $HOME/.noisd/config/config.toml
sed -i 's|^rpc_servers *=.*|rpc_servers = "'$SNAP_RPC,$SNAP_RPC'"|' $HOME/.noisd/config/config.toml
sed -i 's|^trust_height *=.*|trust_height = '$BLOCK_HEIGHT'|' $HOME/.noisd/config/config.toml
sed -i 's|^trust_hash *=.*|trust_hash = "'$TRUST_HASH'"|' $HOME/.noisd/config/config.toml

sudo systemctl daemon-reload
sudo systemctl enable noisd
sudo systemctl start noisd

printLine
echo -e "Check logs:            ${CYAN}sudo journalctl -u $BINARY_NAME -f --no-hostname -o cat ${NC}"
echo -e "Check synchronization: ${CYAN}$BINARY_NAME status 2>&1 | jq .SyncInfo.catching_up${NC}"
echo -e "More commands:         ${CYAN}$CHEAT_SHEET${NC}"
