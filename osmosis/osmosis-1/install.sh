#!/bin/bash

source <(curl -s https://raw.githubusercontent.com/nodejumper-org/cosmos-scripts/master/utils/common.sh)

printLogo

read -r -p "Enter node moniker: " NODE_MONIKER

CHAIN_ID="osmosis-1"
CHAIN_DENOM="uosmo"
BINARY_NAME="osmosisd"
CHEAT_SHEET="https://nodejumper.io/osmosis/cheat-sheet"

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
rm -rf osmosis
git clone https://github.com/osmosis-labs/osmosis
cd osmosis || return
git checkout v12.2.0
make install
osmosisd version # v12.2.0

osmosisd config chain-id $CHAIN_ID
osmosisd init "$NODE_MONIKER" --chain-id $CHAIN_ID

curl https://github.com/osmosis-labs/networks/raw/main/osmosis-1/genesis.json > $HOME/.osmosisd/config/genesis.json
sha256sum $HOME/.osmosisd/config/genesis.json # 1cdb76087fabcca7709fc563b44b5de98aaf297eedc8805aa2884999e6bab06d

sed -i 's|^minimum-gas-prices *=.*|minimum-gas-prices = "0.0001uosmo"|g' $HOME/.osmosisd/config/app.toml
SEEDS="21d7539792ee2e0d650b199bf742c56ae0cf499e@162.55.132.230:2000,295b417f995073d09ff4c6c141bd138a7f7b5922@65.21.141.212:2000,ec4d3571bf709ab78df61716e47b5ac03d077a1a@65.108.43.26:2000,4cb8e1e089bdf44741b32638591944dc15b7cce3@65.108.73.18:2000,f515a8599b40f0e84dfad935ba414674ab11a668@osmosis.blockpane.com:26656,6bcdbcfd5d2c6ba58460f10dbcfde58278212833@osmosis.artifact-staking.io:26656"
PEERS="83c06bc290b6dffe05aa9cec720bedfc118afcbc@osmosis.nodejumper.io:35656"
sed -i 's|^seeds *=.*|seeds = "'$SEEDS'"|; s|^persistent_peers *=.*|persistent_peers = "'$PEERS'"|' $HOME/.osmosisd/config/config.toml

# in case of pruning
sed -i 's|pruning = "default"|pruning = "custom"|g' $HOME/.osmosisd/config/app.toml
sed -i 's|pruning-keep-recent = "0"|pruning-keep-recent = "100"|g' $HOME/.osmosisd/config/app.toml
sed -i 's|pruning-interval = "0"|pruning-interval = "17"|g' $HOME/.osmosisd/config/app.toml
sed -i 's/snapshot-interval *=.*/snapshot-interval = 0/g' $HOME/.osmosisd/config/app.toml

printCyan "5. Starting service and synchronization..." && sleep 1

sudo tee /etc/systemd/system/osmosisd.service  > /dev/null << EOF
[Unit]
Description=Osmosis Node
After=network-online.target
[Service]
User=$USER
ExecStart=$(which osmosisd) start
Restart=on-failure
RestartSec=10
LimitNOFILE=10000
[Install]
WantedBy=multi-user.target
EOF

osmosisd unsafe-reset-all --home $HOME/.osmosisd --keep-addr-book
rm -rf $HOME/.osmosisd/data
cd $HOME/.osmosisd || return

SNAP_NAME=$(curl -s https://snapshots2.nodejumper.io/osmosis/ | egrep -o ">osmosis-1.*\.tar.lz4" | tr -d ">")
echo "Downloading a snapshot..."
curl -# https://snapshots2.nodejumper.io/osmosis/"${SNAP_NAME}" | lz4 -dc - | tar -xf -

sudo systemctl daemon-reload
sudo systemctl enable osmosisd
sudo systemctl start osmosisd

printLine
echo -e "Check logs:            ${CYAN}sudo journalctl -u $BINARY_NAME -f --no-hostname -o cat ${NC}"
echo -e "Check synchronization: ${CYAN}$BINARY_NAME status 2>&1 | jq .SyncInfo.catching_up${NC}"
echo -e "More commands:         ${CYAN}$CHEAT_SHEET${NC}"
