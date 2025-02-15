#!/bin/bash

source <(curl -s https://raw.githubusercontent.com/nodejumper-org/cosmos-scripts/master/utils/common.sh)

printLogo

read -r -p "Enter node moniker: " NODE_MONIKER

CHAIN_ID="testnet-1"
CHAIN_DENOM="uheart"
BINARY_NAME="humansd"
BINARY_VERSION_TAG="v1.0.0"
CHEAT_SHEET="https://nodejumper.io/humans-testnet/cheat-sheet"

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
rm -rf humans
git clone https://github.com/humansdotai/humans
cd humans || return
git checkout v1.0.0
go build -o humansd cmd/humansd/main.go
sudo cp humansd /usr/local/bin/humansd
humansd version

humansd config keyring-backend test
humansd config chain-id $CHAIN_ID
humansd init "$NODE_MONIKER" --chain-id $CHAIN_ID

curl -s https://rpc-testnet.humans.zone/genesis | jq -r .result.genesis > $HOME/.humans/config/genesis.json
curl -s https://snapshots4-testnet.nodejumper.io/humans-testnet/addrbook.json > $HOME/.humans/config/addrbook.json

SEEDS=""
PEERS=""
sed -i 's|^seeds *=.*|seeds = "'$SEEDS'"|; s|^persistent_peers *=.*|persistent_peers = "'$PEERS'"|' $HOME/.humans/config/config.toml

PRUNING_INTERVAL=$(shuf -n1 -e 11 13 17 19 23 29 31 37 41 43 47 53 59 61 67 71 73 79 83 89 97)
sed -i 's|^pruning *=.*|pruning = "custom"|g' $HOME/.humans/config/app.toml
sed -i 's|^pruning-keep-recent  *=.*|pruning-keep-recent = "100"|g' $HOME/.humans/config/app.toml
sed -i 's|^pruning-interval *=.*|pruning-interval = "'$PRUNING_INTERVAL'"|g' $HOME/.humans/config/app.toml
sed -i 's|^snapshot-interval *=.*|snapshot-interval = 2000|g' $HOME/.humans/config/app.toml

sed -i 's|^minimum-gas-prices *=.*|minimum-gas-prices = "0.025uheart"|g' $HOME/.humans/config/app.toml
sed -i 's|^prometheus *=.*|prometheus = true|' $HOME/.humans/config/config.toml
sed -i 's|^timeout_propose *=.*|timeout_propose = "100ms"|' $HOME/.humans/config/config.toml
sed -i 's|^timeout_propose_delta *=.*|timeout_propose_delta = "500ms"|' $HOME/.humans/config/config.toml
sed -i 's|^timeout_prevote *=.*|timeout_prevote = "100ms"|' $HOME/.humans/config/config.toml
sed -i 's|^timeout_prevote_delta *=.*|timeout_prevote_delta = "500ms"|' $HOME/.humans/config/config.toml
sed -i 's|^timeout_precommit *=.*|timeout_precommit = "100ms"|' $HOME/.humans/config/config.toml
sed -i 's|^timeout_precommit_delta *=.*|timeout_precommit_delta = "500ms"|' $HOME/.humans/config/config.toml
sed -i 's|^timeout_commit *=.*|timeout_commit = "1s"|' $HOME/.humans/config/config.toml
sed -i 's|^skip_timeout_commit *=.*|skip_timeout_commit = false|' $HOME/.humans/config/config.toml

printCyan "5. Starting service and synchronization..." && sleep 1

sudo tee /etc/systemd/system/humansd.service > /dev/null << EOF
[Unit]
Description=Humans AI Node
After=network-online.target
[Service]
User=$USER
ExecStart=$(which humansd) start
Restart=on-failure
RestartSec=10
LimitNOFILE=10000
[Install]
WantedBy=multi-user.target
EOF

humansd tendermint unsafe-reset-all --home $HOME/.humans --keep-addr-book

SNAP_RPC="https://humans-testnet.nodejumper.io:443"

LATEST_HEIGHT=$(curl -s $SNAP_RPC/block | jq -r .result.block.header.height);
BLOCK_HEIGHT=$((LATEST_HEIGHT - 2000));
TRUST_HASH=$(curl -s "$SNAP_RPC/block?height=$BLOCK_HEIGHT" | jq -r .result.block_id.hash)

echo $LATEST_HEIGHT $BLOCK_HEIGHT $TRUST_HASH

sed -i 's|^enable *=.*|enable = true|' $HOME/.humans/config/config.toml
sed -i 's|^rpc_servers *=.*|rpc_servers = "'$SNAP_RPC,$SNAP_RPC'"|' $HOME/.humans/config/config.toml
sed -i 's|^trust_height *=.*|trust_height = '$BLOCK_HEIGHT'|' $HOME/.humans/config/config.toml
sed -i 's|^trust_hash *=.*|trust_hash = "'$TRUST_HASH'"|' $HOME/.humans/config/config.toml

sudo systemctl daemon-reload
sudo systemctl enable humansd
sudo systemctl start humansd

printLine
echo -e "Check logs:            ${CYAN}sudo journalctl -u $BINARY_NAME -f --no-hostname -o cat ${NC}"
echo -e "Check synchronization: ${CYAN}$BINARY_NAME status 2>&1 | jq .SyncInfo.catching_up${NC}"
echo -e "More commands:         ${CYAN}$CHEAT_SHEET${NC}"
